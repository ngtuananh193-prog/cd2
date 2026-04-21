import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/now_playing.dart';
import 'package:flute_example/widgets/mp_circle_avatar.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class MPListView extends StatefulWidget {
  const MPListView({super.key});

  @override
  State<MPListView> createState() => _MPListViewState();
}

class _MPListViewState extends State<MPListView> {
  final List<MaterialColor> _colors = Colors.primaries;

  void _showAddToPlaylistDialog(SongData songData, SongModel song) {
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
                  child: Text('Chưa có playlist nào. Hãy tạo playlist trước.'),
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
                    subtitle: Text(
                        '${songData.getPlaylistSongCount(name)} bài hát'),
                    onTap: () {
                      songData.addToPlaylist(name, song.id);
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Đã thêm "${song.title}" vào $name'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
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
    final rootIW = MPInheritedWidget.of(context);
    final songData = rootIW.songData;

    return ListView.builder(
      itemCount: songData.songs.length,
      itemBuilder: (context, int index) {
        final s = songData.songs[index];
        final MaterialColor color = _colors[index % _colors.length];
        final isFav = songData.isFavorite(s.id);

        return ListTile(
          dense: false,
          leading: Hero(
            tag: s.title,
            child: avatar(s, color),
          ),
          title: Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'By ${s.artist ?? "Unknown artist"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.pinkAccent : null,
                  size: 22,
                ),
                onPressed: () {
                  rootIW.onToggleFavorite?.call(s.id);
                  setState(() {});
                },
                tooltip:
                    isFav ? 'Bỏ yêu thích' : 'Yêu thích',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'add_to_playlist') {
                    _showAddToPlaylistDialog(songData, s);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'add_to_playlist',
                    child: ListTile(
                      leading: Icon(Icons.playlist_add),
                      title: Text('Thêm vào Playlist'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            songData.setCurrentIndex(index);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NowPlaying(songData, s),
              ),
            );
          },
        );
      },
    );
  }
}
