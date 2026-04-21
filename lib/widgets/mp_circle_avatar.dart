import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'safe_artwork_widget.dart';

Widget avatar(SongModel song, MaterialColor color) {
  return Material(
    borderRadius: BorderRadius.circular(20.0),
    elevation: 3.0,
    child: SafeArtworkWidget(
      id: song.id,
      type: ArtworkType.AUDIO,
      artworkBorder: BorderRadius.circular(20.0),
      nullArtworkWidget: CircleAvatar(
        backgroundColor: color,
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
        ),
      ),
    ),
  );
}
