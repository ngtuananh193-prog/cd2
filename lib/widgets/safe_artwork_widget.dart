import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flute_example/utils/permission_state.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

/// A widget that safely fetches artwork, respecting permission state and
/// preventing the native "Reply already submitted" crash.
///
/// Uses a **widget-level Future cache** so that rebuilds with the same [id]
/// never trigger a second fetch.  Under the hood, [_ArtworkFetcher] provides
/// global caching + request deduplication + sequential native call throttling.
class SafeArtworkWidget extends StatefulWidget {
  final int id;
  final ArtworkType type;
  final Widget? nullArtworkWidget;
  final BorderRadius? artworkBorder;
  final BoxFit artworkFit;

  const SafeArtworkWidget({
    super.key,
    required this.id,
    required this.type,
    this.nullArtworkWidget,
    this.artworkBorder,
    this.artworkFit = BoxFit.cover,
  });

  @override
  State<SafeArtworkWidget> createState() => _SafeArtworkWidgetState();
}

class _SafeArtworkWidgetState extends State<SafeArtworkWidget> {
  /// Cached future so that rebuilds / didUpdateWidget NO-OPs when id unchanged.
  Future<Uint8List?>? _artworkFuture;
  Uint8List? _artwork;
  bool _isLoading = true;

  /// Tracks the ID we last started a fetch for, to avoid redundant fetches.
  int? _loadedId;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant SafeArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.type != widget.type) {
      _startLoad();
    }
  }

  void _startLoad() {
    // Skip if we already loaded / are loading this exact id.
    if (_loadedId == widget.id && _artworkFuture != null) return;
    _loadedId = widget.id;
    _artworkFuture = _ArtworkFetcher.instance.getArtwork(widget.id, widget.type);
    _artworkFuture!.then((data) {
      if (mounted && _loadedId == widget.id) {
        setState(() {
          _artwork = data;
          _isLoading = false;
        });
      }
    });
    // Reset loading state only when ID actually changed.
    if (_isLoading != true) {
      setState(() => _isLoading = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.nullArtworkWidget ?? const Icon(Icons.music_note);
    final borderRadius = widget.artworkBorder ?? BorderRadius.circular(50.0);

    if (_isLoading || _artwork == null || _artwork!.isEmpty) {
      return Container(
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: fallback,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.memory(
        _artwork!,
        fit: widget.artworkFit,
        // If the bytes are corrupt / undecodable, show fallback.
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

// ── Singleton artwork fetcher with deduplication + throttling ─────────────────

class _ArtworkFetcher {
  static final _ArtworkFetcher instance = _ArtworkFetcher._();
  _ArtworkFetcher._();

  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// LRU cache of completed artwork.  Capped at [_maxCacheEntries] to prevent
  /// unbounded memory growth on devices with thousands of songs.
  static const _maxCacheEntries = 200;
  final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap();

  /// In-flight requests: ensures that only ONE native call per cache key
  /// is active at any time.  Subsequent callers for the same key will await
  /// the same Completer, preventing duplicate MethodChannel calls.
  final Map<String, Completer<Uint8List?>> _inFlight = {};

  /// Sequential queue: prevents more than [_maxConcurrent] MethodChannel calls
  /// from being active simultaneously.  The `on_audio_query_pluse` Kotlin side
  /// uses a single Result reference and crashes if multiple calls overlap.
  static const _maxConcurrent = 1;
  int _activeCalls = 0;
  final Queue<Completer<void>> _queue = Queue();

  /// Acquire a slot in the throttle queue.  Resolves immediately if a slot is
  /// free, otherwise waits until a previous call finishes.
  Future<void> _acquireSlot() async {
    if (_activeCalls < _maxConcurrent) {
      _activeCalls++;
      return;
    }
    final waiter = Completer<void>();
    _queue.add(waiter);
    await waiter.future;
  }

  void _releaseSlot() {
    if (_queue.isNotEmpty) {
      _queue.removeFirst().complete();
    } else {
      _activeCalls--;
    }
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    // ── Guard 1: Wait for permission resolution ──
    if (!AudioPermissionState.isResolved) {
      final granted = await AudioPermissionState.ready;
      if (!granted) return null;
    }
    if (!AudioPermissionState.granted) return null;

    // ── Guard 2: Check LRU cache ──
    final cacheKey = '${id}_${type.name}';
    if (_cache.containsKey(cacheKey)) {
      // Move to end (most recently used).
      final value = _cache.remove(cacheKey);
      _cache[cacheKey] = value;
      return value;
    }

    // ── Guard 3: Deduplicate in-flight requests ──
    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey]!.future;
    }

    final completer = Completer<Uint8List?>();
    _inFlight[cacheKey] = completer;

    try {
      // ── Guard 4: Throttle concurrent native calls ──
      await _acquireSlot();

      final result = await _audioQuery.queryArtwork(
        id,
        type,
        format: ArtworkFormat.JPEG,
        size: 200,
        quality: 100,
      );

      _releaseSlot();

      // Evict oldest entry if cache is full.
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = result;
      completer.complete(result);
      return result;
    } catch (e) {
      _releaseSlot();
      _cache[cacheKey] = null;
      completer.complete(null);
      return null;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }
}
