import 'package:flute_example/pages/playlist_detail_page.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo Playlist mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên playlist',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _createPlaylist(controller.text, dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => _createPlaylist(controller.text, dialogContext),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _createPlaylist(String name, BuildContext dialogContext) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final rootIW = MPInheritedWidget.of(context);
    final success = rootIW.songData.createPlaylist(trimmed);

    Navigator.pop(dialogContext);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trimmed == 'Yêu thích'
                ? 'Không thể tạo playlist trùng tên "Yêu thích"'
                : 'Playlist "$trimmed" đã tồn tại',
          ),
        ),
      );
      return;
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo playlist "$trimmed"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootIW = MPInheritedWidget.of(context);
    final songData = rootIW.songData;
    final names = songData.playlistNames;

    return Scaffold(
      body: names.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có playlist nào',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Nhấn nút + để tạo playlist mới'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: names.length,
              itemBuilder: (context, index) {
                final name = names[index];
                final count = songData.getPlaylistSongCount(name);
                final isFavorites = name == 'Yêu thích';

                return Dismissible(
                  key: ValueKey('playlist_$name'),
                  direction: isFavorites
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (isFavorites) return false;
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xóa playlist'),
                        content:
                            Text('Bạn có chắc muốn xóa playlist "$name"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    songData.deletePlaylist(name);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã xóa playlist "$name"')),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isFavorites
                          ? Colors.pinkAccent
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        isFavorites
                            ? Icons.favorite_rounded
                            : Icons.queue_music_rounded,
                        color: isFavorites
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            isFavorites ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('$count bài hát'),
                    trailing: isFavorites
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailPage(playlistName: name),
                        ),
                      );
                      // Refresh counts after returning from detail page.
                      if (mounted) setState(() {});
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        tooltip: 'Tạo Playlist',
        child: const Icon(Icons.add),
      ),
    );
  }
}
