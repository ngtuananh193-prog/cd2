import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:on_audio_query_pluse/on_audio_query.dart';

import 'playlist_storage.dart';

class SongData {
  SongData(List<SongModel> songs) : _songs = songs;

  final AudioPlayer audioPlayer = AudioPlayer();
  List<SongModel> _songs;
  int _currentSongIndex = -1;

  /// Playlist data: name -> list of song IDs.
  final Map<String, List<int>> _playlists = {};

  /// Set of song IDs marked as favorite.
  final Set<int> _favorites = {};

  /// File paths of manually-added songs (for persistence).
  final List<String> _manualSongPaths = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  List<SongModel> get songs => _songs;
  int get length => _songs.length;
  int get songNumber => _currentSongIndex + 1;
  int get currentIndex => _currentSongIndex;

  Map<String, List<int>> get playlists => Map.unmodifiable(_playlists);
  Set<int> get favorites => Set.unmodifiable(_favorites);
  List<String> get manualSongPaths => List.unmodifiable(_manualSongPaths);

  // ── Song management ────────────────────────────────────────────────────────

  void setSongs(List<SongModel> songs) {
    _songs = songs;
    _currentSongIndex = songs.isEmpty ? -1 : 0;
  }

  void addSongs(List<SongModel> songs) {
    if (songs.isEmpty) {
      return;
    }

    final existingPaths = _songs.map((song) => song.data).toSet();
    final mergedSongs = <SongModel>[..._songs];

    for (final song in songs) {
      if (existingPaths.add(song.data)) {
        mergedSongs.add(song);
      }
    }

    _songs = mergedSongs;
    if (_currentSongIndex < 0 && _songs.isNotEmpty) {
      _currentSongIndex = 0;
    }
  }

  /// Track manually-added file paths for persistence.
  void addManualPaths(List<String> paths) {
    final existing = _manualSongPaths.toSet();
    for (final p in paths) {
      if (existing.add(p)) {
        _manualSongPaths.add(p);
      }
    }
  }

  static List<SongModel> buildManualSongs(List<String> filePaths) {
    return filePaths.map(buildManualSong).toList(growable: false);
  }

  static SongModel buildManualSong(String filePath) {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final title = path.basenameWithoutExtension(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final extension = path.extension(filePath).replaceFirst('.', '');

    return SongModel({
      '_id': filePath.hashCode.abs(),
      '_data': filePath,
      '_uri': filePath,
      '_display_name': fileName,
      '_display_name_wo_ext': title,
      '_size': size,
      'album': 'Manual import',
      'album_id': null,
      'artist': 'Unknown artist',
      'artist_id': null,
      'genre': null,
      'genre_id': null,
      'bookmark': null,
      'composer': null,
      'date_added': null,
      'date_modified': null,
      'duration': null,
      'title': title.isEmpty ? fileName : title,
      'track': null,
      'file_extension': extension,
      'is_alarm': false,
      'is_audiobook': false,
      'is_music': true,
      'is_notification': false,
      'is_podcast': false,
      'is_ringtone': false,
    });
  }

  // ── Playback navigation ────────────────────────────────────────────────────

  void setCurrentIndex(int index) {
    _currentSongIndex = index;
  }

  SongModel? get nextSong {
    if (_songs.isEmpty) {
      return null;
    }
    if (_currentSongIndex < length - 1) {
      _currentSongIndex++;
    }
    if (_currentSongIndex >= length) {
      return null;
    }
    return _songs[_currentSongIndex];
  }

  SongModel? get randomSong {
    if (_songs.isEmpty) {
      return null;
    }
    final random = Random();
    return _songs[random.nextInt(_songs.length)];
  }

  SongModel? get prevSong {
    if (_songs.isEmpty) {
      return null;
    }
    if (_currentSongIndex > 0) {
      _currentSongIndex--;
    }
    if (_currentSongIndex < 0) {
      return null;
    }
    return _songs[_currentSongIndex];
  }

  // ── Favorites ──────────────────────────────────────────────────────────────

  bool isFavorite(int songId) => _favorites.contains(songId);

  void toggleFavorite(int songId) {
    if (_favorites.contains(songId)) {
      _favorites.remove(songId);
    } else {
      _favorites.add(songId);
    }
    _persistFavorites();
  }

  /// Return songs that are in the favorites set.
  List<SongModel> get favoriteSongs {
    return _songs.where((s) => _favorites.contains(s.id)).toList();
  }

  // ── Playlist management ────────────────────────────────────────────────────

  List<String> get playlistNames {
    // "Yêu thích" always first if it exists.
    final names = _playlists.keys.toList();
    names.remove('Yêu thích');
    return ['Yêu thích', ...names];
  }

  List<SongModel> getPlaylistSongs(String playlistName) {
    if (playlistName == 'Yêu thích') {
      return favoriteSongs;
    }
    final ids = _playlists[playlistName];
    if (ids == null) return [];
    // Preserve playlist order
    final songMap = {for (final s in _songs) s.id: s};
    return ids.map((id) => songMap[id]).whereType<SongModel>().toList();
  }

  int getPlaylistSongCount(String playlistName) {
    if (playlistName == 'Yêu thích') {
      return _favorites.length;
    }
    return _playlists[playlistName]?.length ?? 0;
  }

  bool createPlaylist(String name) {
    if (name.isEmpty || _playlists.containsKey(name) || name == 'Yêu thích') {
      return false;
    }
    _playlists[name] = [];
    _persistPlaylists();
    return true;
  }

  bool deletePlaylist(String name) {
    if (name == 'Yêu thích') return false; // Cannot delete favorites
    final removed = _playlists.remove(name) != null;
    if (removed) _persistPlaylists();
    return removed;
  }

  void addToPlaylist(String playlistName, int songId) {
    if (playlistName == 'Yêu thích') {
      if (!_favorites.contains(songId)) {
        _favorites.add(songId);
        _persistFavorites();
      }
      return;
    }
    final list = _playlists[playlistName];
    if (list == null) return;
    if (!list.contains(songId)) {
      list.add(songId);
      _persistPlaylists();
    }
  }

  void removeFromPlaylist(String playlistName, int songId) {
    if (playlistName == 'Yêu thích') {
      _favorites.remove(songId);
      _persistFavorites();
      return;
    }
    final list = _playlists[playlistName];
    if (list == null) return;
    list.remove(songId);
    _persistPlaylists();
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  Future<void> loadFromStorage() async {
    final storage = PlaylistStorage.instance;
    final savedFavorites = await storage.loadFavorites();
    _favorites.addAll(savedFavorites);

    final savedPlaylists = await storage.loadPlaylists();
    _playlists.addAll(savedPlaylists);

    final savedPaths = await storage.loadManualSongPaths();
    _manualSongPaths.addAll(savedPaths);
  }

  Future<void> _persistFavorites() async {
    await PlaylistStorage.instance.saveFavorites(_favorites);
  }

  Future<void> _persistPlaylists() async {
    await PlaylistStorage.instance.savePlaylists(_playlists);
  }

  Future<void> persistManualPaths() async {
    await PlaylistStorage.instance.saveManualSongPaths(_manualSongPaths);
  }
}
