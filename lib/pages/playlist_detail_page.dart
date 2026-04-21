import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/now_playing.dart';
import 'package:flute_example/widgets/mp_circle_avatar.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';

class PlaylistDetailPage extends StatefulWidget {
  final String playlistName;

  const PlaylistDetailPage({super.key, required this.playlistName});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final List<MaterialColor> _colors = Colors.primaries;

  void _showAddSongsSheet(SongData songData) {
    final playlistSongIds = widget.playlistName == 'Yêu thích'
        ? songData.favorites
        : (songData.playlists[widget.playlistName] ?? []).toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            final available = songData.songs
                .where((s) => !playlistSongIds.contains(s.id))
                .toList();

            if (available.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Tất cả bài hát đã có trong playlist này'),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Thêm bài hát',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: available.length,
                    itemBuilder: (_, idx) {
                      final song = available[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _colors[idx % _colors.length].shade700,
                          child: const Icon(Icons.music_note,
                              color: Colors.white, size: 18),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(song.artist ?? 'Unknown artist'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            songData.addToPlaylist(
                                widget.playlistName, song.id);
                            Navigator.pop(sheetContext);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Đã thêm "${song.title}" vào ${widget.playlistName}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootIW = MPInheritedWidget.of(context);
    final songData = rootIW.songData;
    final songs = songData.getPlaylistSongs(widget.playlistName);
    final isFavorites = widget.playlistName == 'Yêu thích';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Thêm bài hát',
            onPressed: songData.songs.isEmpty
                ? null
                : () => _showAddSongsSheet(songData),
          ),
        ],
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFavorites
                        ? Icons.favorite_border_rounded
                        : Icons.queue_music_rounded,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFavorites
                        ? 'Chưa có bài hát yêu thích'
                        : 'Playlist trống',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFavorites
                        ? 'Nhấn icon ❤️ trên bài hát để thêm vào đây'
                        : 'Nhấn nút + phía trên để thêm bài hát',
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final color = _colors[index % _colors.length];

                return Dismissible(
                  key: ValueKey('playlist_song_${song.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.remove_circle, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    songData.removeFromPlaylist(widget.playlistName, song.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Đã xóa "${song.title}" khỏi ${widget.playlistName}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: Hero(
                      tag: 'playlist_${widget.playlistName}_${song.title}',
                      child: avatar(song, color),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'By ${song.artist ?? "Unknown artist"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      // Find global index to set current
                      final globalIdx =
                          songData.songs.indexWhere((s) => s.id == song.id);
                      if (globalIdx >= 0) {
                        songData.setCurrentIndex(globalIdx);
                      }
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NowPlaying(songData, song),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
