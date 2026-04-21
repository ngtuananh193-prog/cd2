import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'safe_artwork_widget.dart';

class AlbumUI extends StatefulWidget {
  final SongModel? song;
  final Duration? position;
  final Duration? duration;

  const AlbumUI(this.song, this.duration, this.position, {super.key});

  @override
  AlbumUIState createState() => AlbumUIState();
}

class AlbumUIState extends State<AlbumUI> with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.elasticOut,
    );
    animation.addListener(() {
      if (mounted) setState(() {});
    });
    animationController.forward();
  }

  @override
  void dispose() {
    // IMPORTANT: dispose controller BEFORE super.dispose().
    // The original code had the wrong order which can cause crashes
    // when the ticker is still active during disposal.
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    final myHero = Hero(
      tag: song?.title ?? 'unknown-song',
      child: Material(
        borderRadius: BorderRadius.circular(5.0),
        elevation: 5.0,
        child: song != null
            ? SafeArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkBorder: BorderRadius.circular(5.0),
                nullArtworkWidget: Image.asset(
                  "assets/music_record.jpeg",
                  fit: BoxFit.cover,
                  height: 250.0,
                ),
              )
            : Image.asset(
                "assets/music_record.jpeg",
                fit: BoxFit.cover,
                height: 250.0,
              ),
      ),
    );

    final progress = widget.duration != null &&
            widget.duration!.inMilliseconds > 0 &&
            widget.position != null
        ? (widget.position!.inMilliseconds.toDouble() /
            widget.duration!.inMilliseconds.toDouble())
        : 0.0;

    return SizedBox.fromSize(
      size: Size(animation.value * 250.0, animation.value * 250.0),
      child: Stack(
        children: <Widget>[
          myHero,
          Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.symmetric(horizontal: 0.8),
            child: Material(
              borderRadius: BorderRadius.circular(5.0),
              child: Stack(children: [
                LinearProgressIndicator(
                  value: 1.0,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.24),
                  ),
                ),
                LinearProgressIndicator(
                  value: progress,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.secondary,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
