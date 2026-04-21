import 'dart:async';

import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/widgets/mp_album_ui.dart';
import 'package:flute_example/widgets/mp_blur_filter.dart';
import 'package:flute_example/widgets/mp_blur_widget.dart';
import 'package:flute_example/widgets/mp_control_button.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:on_audio_query_pluse/on_audio_query.dart';

class NowPlaying extends StatefulWidget {
  final SongModel song;
  final SongData songData;
  final bool nowPlayTap;

  const NowPlaying(this.songData, this.song,
      {super.key, this.nowPlayTap = false});

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  late final ja.AudioPlayer _audioPlayer;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;

  Duration? duration;
  Duration position = Duration.zero;
  SongModel? song;
  bool isMuted = false;

  /// Guards against concurrent play/next/prev calls that could cause
  /// overlapping setAudioSource → play sequences.
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = widget.songData.audioPlayer;
    _initPlayer();
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    song = widget.song;

    _durationSubscription = _audioPlayer.durationStream.listen((value) {
      if (!mounted) return;
      setState(() => duration = value);
    });

    _positionSubscription = _audioPlayer.positionStream.listen((value) {
      if (!mounted) return;
      setState(() => position = value);
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((value) {
      if (!mounted) return;
      if (value.processingState == ja.ProcessingState.completed) {
        _handleComplete();
      }
    });

    if (!widget.nowPlayTap) {
      await stop();
    }
    await play(widget.song);
  }

  Future<void> _handleComplete() async {
    final nextSong = widget.songData.nextSong;
    if (nextSong == null) {
      await stop();
      return;
    }
    await play(nextSong);
  }

  /// Play a song, guarded by [_isTransitioning] to prevent concurrent
  /// setAudioSource calls which can cause just_audio crashes.
  Future<void> play(SongModel s) async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      if (s.data.startsWith('content://')) {
        await _audioPlayer.setAudioSource(
          ja.AudioSource.uri(Uri.parse(s.data)),
        );
      } else {
        await _audioPlayer.setFilePath(s.data);
      }
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() => song = s);
    } catch (e) {
      // Silently handle — e.g. file not found, unsupported format.
      debugPrint('NowPlaying.play error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    if (!mounted) return;
    setState(() => position = Duration.zero);
  }

  Future<void> next(SongData songData) async {
    if (_isTransitioning) return;
    await stop();
    final nextSong = songData.nextSong;
    if (nextSong != null) {
      await play(nextSong);
    }
  }

  Future<void> prev(SongData songData) async {
    if (_isTransitioning) return;
    await stop();
    final previousSong = songData.prevSong;
    if (previousSong != null) {
      await play(previousSong);
    }
  }

  Future<void> mute(bool muted) async {
    await _audioPlayer.setVolume(muted ? 0.0 : 1.0);
    if (!mounted) return;
    setState(() => isMuted = muted);
  }

  String _formatDuration(Duration? value) {
    if (value == null) return '';
    final text = value.toString();
    return text.contains('.') ? text.split('.').first : text;
  }

  void _toggleFavorite() {
    final current = song;
    if (current == null) return;
    setState(() {
      widget.songData.toggleFavorite(current.id);
    });
  }

  void _showAddToPlaylistSheet() {
    final current = song;
    if (current == null) return;
    final songData = widget.songData;
    final names = songData.playlistNames;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Thêm vào Playlist',
                  style: Theme.of(sheetCtx).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              if (names.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có playlist nào.'),
                )
              else
                ...names.map(
                  (name) => ListTile(
                    leading: Icon(
                      name == 'Yêu thích'
                          ? Icons.favorite_rounded
                          : Icons.queue_music_rounded,
                      color: name == 'Yêu thích' ? Colors.pinkAccent : null,
                    ),
                    title: Text(name),
                    onTap: () {
                      songData.addToPlaylist(name, current.id);
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Đã thêm "${current.title}" vào $name'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = song;
    final isFav =
        currentSong != null && widget.songData.isFavorite(currentSong.id);

    Widget buildPlayer() => Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Column(
              children: <Widget>[
                Text(
                  song?.title ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  song?.artist ?? 'Unknown artist',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                )
              ],
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              ControlButton(Icons.skip_previous, () => prev(widget.songData)),
              ControlButton(
                _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                _audioPlayer.playing ? pause : _audioPlayer.play,
              ),
              ControlButton(Icons.skip_next, () => next(widget.songData)),
            ]),
            duration == null
                ? const SizedBox.shrink()
                : Slider(
                    value: position.inMilliseconds.toDouble().clamp(
                          0.0,
                          duration!.inMilliseconds.toDouble(),
                        ),
                    onChanged: (double value) => _audioPlayer
                        .seek(Duration(milliseconds: value.round())),
                    min: 0.0,
                    max: duration!.inMilliseconds.toDouble(),
                  ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                duration == null
                    ? ''
                    : '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(fontSize: 24.0),
              )
            ]),
            const Padding(
              padding: EdgeInsets.only(bottom: 20.0),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.pinkAccent : Colors.white70,
                  ),
                  tooltip: isFav ? 'Bỏ yêu thích' : 'Yêu thích',
                  onPressed: _toggleFavorite,
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  color: Colors.white70,
                  tooltip: 'Thêm vào Playlist',
                  onPressed: _showAddToPlaylistSheet,
                ),
                IconButton(
                  icon: Icon(
                    isMuted ? Icons.headset : Icons.headset_off,
                    color: Theme.of(context).unselectedWidgetColor,
                  ),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => mute(!isMuted),
                ),
              ],
            ),
          ]),
        );

    final playerUI = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AlbumUI(song, duration, position),
        Material(
          color: Colors.transparent,
          child: buildPlayer(),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[blurWidget(song), blurFilter(), playerUI],
        ),
      ),
    );
  }
}
