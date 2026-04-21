import 'package:flute_example/data/song_data.dart';
import 'package:flutter/material.dart';

class MPInheritedWidget extends InheritedWidget {
  final SongData songData;
  final bool isLoading;
  final Future<void> Function()? onAddManualSongs;
  final void Function(int songId)? onToggleFavorite;
  final void Function()? onRefreshSongs;

  const MPInheritedWidget(
    this.songData,
    this.isLoading, {
    required super.child,
    super.key,
    this.onAddManualSongs,
    this.onToggleFavorite,
    this.onRefreshSongs,
  });

  static MPInheritedWidget of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MPInheritedWidget>()!;
  }

  @override
  bool updateShouldNotify(MPInheritedWidget oldWidget) =>
      songData != oldWidget.songData ||
      isLoading != oldWidget.isLoading ||
      onAddManualSongs != oldWidget.onAddManualSongs ||
      onToggleFavorite != oldWidget.onToggleFavorite ||
      onRefreshSongs != oldWidget.onRefreshSongs;
}
