import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/root_page.dart';
import 'package:flute_example/utils/permission_state.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final SongData _songData = SongData(const []);
  bool _isLoading = true;
  String? _errorMessage;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;

  /// Guards against concurrent / re-entrant calls to [_initPlatformState].
  bool _isInitializing = false;

  /// Timestamp of the last successful [_initPlatformState] completion.
  /// Used to debounce rapid retry taps.
  DateTime? _lastInitTime;

  /// Minimum interval between successive [_initPlatformState] runs.
  static const _initDebounce = Duration(seconds: 2);

  /// Set to `true` when the user taps "Open Settings" so we know to
  /// re-check permission on the next resume.  Cleared after the check.
  bool _waitingForSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _songData.audioPlayer.dispose();
    super.dispose();
  }

  /// Re-check permission ONLY when the user is returning from the system
  /// Settings app (i.e. they tapped "Open Settings" for a permanently-denied
  /// permission).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettingsReturn) {
      _waitingForSettingsReturn = false;
      _initPlatformState(bypassDebounce: true);
    }
  }

  // ── Permission handling ─────────────────────────────────────────────────────

  /// Request the correct media permission using permission_handler,
  /// then sync with the on_audio_query plugin so its internal state
  /// also recognises the grant (prevents "Reply already submitted" crash).
  ///
  /// Returns `true` only when BOTH the system AND the plugin agree that
  /// the app has media permission.
  Future<bool> _requestAndSyncPermission() async {
    // ── Step 1: System-level permission via permission_handler ──
    var status = await Permission.audio.status;
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }
    // Fallback for Android 12 and below (READ_EXTERNAL_STORAGE)
    if (!status.isGranted) {
      status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    }

    if (!status.isGranted) {
      final audioPerm = await Permission.audio.status;
      final storagePerm = await Permission.storage.status;
      _permissionPermanentlyDenied =
          audioPerm.isPermanentlyDenied || storagePerm.isPermanentlyDenied;
      return false;
    }

    // ── Step 2: Small delay – let the OS propagate the grant ──
    await Future.delayed(const Duration(milliseconds: 300));

    // ── Step 3: Sync with on_audio_query plugin ──
    // The plugin maintains its own permission state.  If we skip this step,
    // its native querySongs / queryArtwork will still think there is no
    // access and hit the buggy double-reply code path.
    try {
      bool pluginReady = await _audioQuery.permissionsStatus();
      if (!pluginReady) {
        pluginReady = await _audioQuery.permissionsRequest();
      }
      return pluginReady;
    } catch (_) {
      return false;
    }
  }

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Central initialization: request permission → query songs → update UI.
  ///
  /// **Concurrency-safe**:
  /// - [_isInitializing] prevents re-entrant execution.
  /// - [_lastInitTime] + [_initDebounce] prevents rapid successive calls
  ///   from button mashing / widget rebuilds.
  Future<void> _initPlatformState({bool bypassDebounce = false}) async {
    // Prevent concurrent / re-entrant execution.
    if (_isInitializing || !mounted) return;

    // Debounce: refuse to run again within [_initDebounce] of the last run,
    // unless explicitly bypassed (e.g. returning from Settings).
    if (!bypassDebounce && _lastInitTime != null) {
      final elapsed = DateTime.now().difference(_lastInitTime!);
      if (elapsed < _initDebounce) return;
    }

    _isInitializing = true;

    // Reset the permission completer so that any widgets currently awaiting
    // `AudioPermissionState.ready` will re-await the new resolution.
    AudioPermissionState.reset();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _permissionDenied = false;
      _permissionPermanentlyDenied = false;
    });

    try {
      // Load saved data (favorites, playlists, manual song paths) first.
      await _songData.loadFromStorage();

      if (Platform.isAndroid) {
        final granted = await _requestAndSyncPermission();

        // ── CRITICAL: Resolve permission state BEFORE any native query ──
        // This unblocks SafeArtworkWidget instances that await
        // AudioPermissionState.ready.
        AudioPermissionState.resolve(granted);

        if (!granted) {
          // Still load any previously-saved manual songs.
          await _loadSavedManualSongs();

          if (!mounted) {
            _isInitializing = false;
            return;
          }
          setState(() {
            _isLoading = false;
            _permissionDenied = true;
            _errorMessage = _songData.songs.isEmpty
                ? 'Quyền truy cập bộ nhớ bị từ chối.\nVui lòng cấp quyền để quét nhạc, hoặc thêm bài hát thủ công.'
                : null;
          });
          _isInitializing = false;
          _lastInitTime = DateTime.now();
          return;
        }
      } else {
        // Non-Android platforms don't need runtime permission.
        AudioPermissionState.resolve(true);
      }

      // Query ALL songs on the device (single call, result cached in _songData).
      final songs = await _querySongsFromDevice();

      // Merge scanned songs with any saved manual songs.
      _songData.setSongs(songs);
      await _loadSavedManualSongs();

      if (_songData.songs.isEmpty) {
        _errorMessage =
            'Không tìm thấy nhạc. Bạn có thể thêm bài hát thủ công.';
      } else {
        _errorMessage = null;
      }
    } catch (error) {
      _errorMessage = 'Lỗi khi tải nhạc: $error';
      // Even on error, resolve permission so widgets aren't blocked forever.
      if (!AudioPermissionState.isResolved) {
        AudioPermissionState.resolve(false);
      }
    }

    if (!mounted) {
      _isInitializing = false;
      return;
    }

    setState(() {
      _isLoading = false;
    });
    _isInitializing = false;
    _lastInitTime = DateTime.now();
  }

  /// Query all songs from the device via [OnAudioQuery], filtering to
  /// files with duration >= 30 seconds.
  ///
  /// CRITICAL: Guarded by [AudioPermissionState.granted].  The native plugin
  /// crashes with "Reply already submitted" if querySongs is invoked before
  /// the plugin's internal permission check passes.
  Future<List<SongModel>> _querySongsFromDevice() async {
    if (!Platform.isAndroid || !AudioPermissionState.granted) {
      return const <SongModel>[];
    }

    try {
      final allSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter: only songs with duration >= 30 000 ms (30 seconds).
      return allSongs.where((song) {
        final durationMs = song.duration ?? 0;
        return durationMs >= 30000;
      }).toList();
    } catch (e) {
      return const <SongModel>[];
    }
  }

  /// Load manually-added songs from persistent storage and merge them.
  Future<void> _loadSavedManualSongs() async {
    final paths = _songData.manualSongPaths;
    if (paths.isEmpty) return;

    final validPaths = paths.where((p) => File(p).existsSync()).toList();
    final manual = SongData.buildManualSongs(validPaths);
    _songData.addSongs(manual);
  }

  Future<void> _addManualSongs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
        withData: false,
      );

      final filePaths = result?.files
              .map((file) => file.path)
              .whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      if (filePaths.isEmpty) return;

      final manualSongs = SongData.buildManualSongs(filePaths);
      if (manualSongs.isEmpty) return;

      _songData.addSongs(manualSongs);
      _songData.addManualPaths(filePaths);
      await _songData.persistManualPaths();

      if (!mounted) return;

      setState(() {
        _errorMessage = null;
        _permissionDenied = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Không thể thêm bài hát: $error';
        _isLoading = false;
      });
    }
  }

  void _toggleFavorite(int songId) {
    setState(() {
      _songData.toggleFavorite(songId);
    });
  }

  Future<void> _retryPermission() async {
    await _initPlatformState(bypassDebounce: true);
  }

  Future<void> _openSettings() async {
    _waitingForSettingsReturn = true;
    await openAppSettings();
  }

  Widget _buildPermissionFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _permissionDenied
                  ? Icons.lock_outlined
                  : Icons.library_music_outlined,
              size: 64,
              color: _permissionDenied ? Colors.orange : null,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Quyền truy cập bị từ chối.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_permissionDenied && _permissionPermanentlyDenied)
                  ElevatedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Mở Cài đặt'),
                  ),
                if (_permissionDenied && !_permissionPermanentlyDenied)
                  ElevatedButton.icon(
                    onPressed: _retryPermission,
                    icon: const Icon(Icons.security),
                    label: const Text('Cấp quyền'),
                  ),
                ElevatedButton.icon(
                  onPressed: _addManualSongs,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm thủ công'),
                ),
                if (!_permissionDenied)
                  OutlinedButton.icon(
                    onPressed: () => _initPlatformState(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Quét lại'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child =
        _errorMessage == null ? const RootPage() : _buildPermissionFallback();

    return MPInheritedWidget(
      _songData,
      _isLoading,
      onAddManualSongs: _addManualSongs,
      onToggleFavorite: _toggleFavorite,
      onRefreshSongs: () => _initPlatformState(),
      child: child,
    );
  }
}
