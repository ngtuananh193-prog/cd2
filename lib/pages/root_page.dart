import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/now_playing.dart';
import 'package:flute_example/pages/playlist_page.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flute_example/widgets/mp_lisview.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final rootIW = MPInheritedWidget.of(context);
    final songData = rootIW.songData;
    final songs = songData.songs;
    final manualAddSongs = rootIW.onAddManualSongs;

    // ── Navigation helpers ──────────────────────────────────────────────────

    void goToNowPlaying(SongModel song, {bool nowPlayTap = false}) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => NowPlaying(
            rootIW.songData,
            song,
            nowPlayTap: nowPlayTap,
          ),
        ),
      );
    }

    void shuffleSongs() {
      final randomSong = rootIW.songData.randomSong;
      if (randomSong != null) {
        goToNowPlaying(randomSong);
      }
    }

    // ── Tab bodies ──────────────────────────────────────────────────────────

    Widget allSongsTab() {
      if (rootIW.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (songs.isEmpty) {
        return _emptyState(manualAddSongs);
      }
      return const Scrollbar(child: MPListView());
    }

    Widget favoritesTab() {
      final favSongs = songData.favoriteSongs;
      if (favSongs.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có bài hát yêu thích',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              const Text('Nhấn icon ❤️ trên bài hát bất kỳ'),
            ],
          ),
        );
      }
      return _FavoriteListView(
        favSongs: favSongs,
        songData: songData,
        onTap: (song) {
          final idx = songs.indexWhere((s) => s.id == song.id);
          if (idx >= 0) songData.setCurrentIndex(idx);
          goToNowPlaying(song);
        },
        onToggleFavorite: (songId) {
          rootIW.onToggleFavorite?.call(songId);
          setState(() {});
        },
      );
    }

    // ── Main scaffold ───────────────────────────────────────────────────────

    final bodies = [
      allSongsTab(),
      const PlaylistPage(),
      favoritesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Music Player'),
        actions: <Widget>[
          if (manualAddSongs != null)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm thủ công',
              onPressed: () async {
                await manualAddSongs();
                if (mounted) setState(() {});
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: InkWell(
                child: const Text('Now Playing'),
                onTap: songs.isEmpty
                    ? null
                    : () => goToNowPlaying(
                          songs[songData.currentIndex < 0
                              ? 0
                              : songData.currentIndex],
                          nowPlayTap: true,
                        ),
              ),
            ),
          ),
        ],
      ),
      body: bodies[_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Tất cả',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music),
            label: 'Playlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Yêu thích',
          ),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: shuffleSongs,
              child: const Icon(Icons.shuffle),
            )
          : null,
    );
  }

  Widget _emptyState(Future<void> Function()? manualAddSongs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('Không tìm thấy bài hát trên thiết bị.'),
            if (manualAddSongs != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await manualAddSongs();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm thủ công'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Favorites list ──────────────────────────────────────────────────────────

class _FavoriteListView extends StatelessWidget {
  final List<SongModel> favSongs;
  final SongData songData;
  final void Function(SongModel song) onTap;
  final void Function(int songId) onToggleFavorite;

  const _FavoriteListView({
    required this.favSongs,
    required this.songData,
    required this.onTap,
    required this.onToggleFavorite,
  });

  static const List<MaterialColor> _colors = Colors.primaries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: favSongs.length,
      itemBuilder: (context, index) {
        final song = favSongs[index];
        final color = _colors[index % _colors.length];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.shade700,
            child:
                const Icon(Icons.music_note, color: Colors.white, size: 18),
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
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            onPressed: () => onToggleFavorite(song.id),
          ),
          onTap: () => onTap(song),
        );
      },
    );
  }
}
