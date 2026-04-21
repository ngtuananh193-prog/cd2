import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'safe_artwork_widget.dart';

Widget blurWidget(SongModel? song) {
  return Hero(
    tag: song?.artist ?? 'unknown-artist',
    child: Container(
      decoration: const BoxDecoration(),
      child: song != null
          ? SafeArtworkWidget(
              id: song.id,
              type: ArtworkType.AUDIO,
              artworkFit: BoxFit.cover,
              nullArtworkWidget: Image.asset(
                "assets/lady.jpeg",
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              "assets/lady.jpeg",
              fit: BoxFit.cover,
            ),
    ),
  );
}
