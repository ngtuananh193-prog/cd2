import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for playlists, favorites, and manually-added songs.
///
/// Data is stored in [SharedPreferences] as JSON so that it survives
/// app restarts.
class PlaylistStorage {
  PlaylistStorage._();

  static final PlaylistStorage instance = PlaylistStorage._();

  static const String _kManualSongPaths = 'manual_song_paths';
  static const String _kFavoriteIds = 'favorite_ids';
  static const String _kPlaylists = 'playlists';
  static const String _kPlaylistOrder = 'playlist_order';

  // ---------------------------------------------------------------------------
  // Manual-song paths
  // ---------------------------------------------------------------------------

  /// Returns the file paths of songs the user added manually.
  Future<List<String>> loadManualSongPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kManualSongPaths) ?? [];
  }

  /// Persists the file paths of manually-added songs.
  Future<void> saveManualSongPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kManualSongPaths, paths);
  }

  // ---------------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------------

  /// Returns the set of song IDs that the user has marked as favorite.
  Future<Set<int>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavoriteIds) ?? [];
    return list.map(int.parse).toSet();
  }

  /// Persists the favorite song IDs.
  Future<void> saveFavorites(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kFavoriteIds,
      ids.map((id) => id.toString()).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Playlists  (name -> list of song IDs)
  // ---------------------------------------------------------------------------

  /// Returns all playlists as `{ name: [songId, …] }`.
  Future<Map<String, List<int>>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaylists);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((e) => e as int).toList(),
      ),
    );
  }

  /// Persists all playlists.
  Future<void> savePlaylists(Map<String, List<int>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaylists, jsonEncode(playlists));
  }

  /// Returns the display-order of playlist names.
  Future<List<String>> loadPlaylistOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kPlaylistOrder) ?? [];
  }

  /// Persists the playlist ordering.
  Future<void> savePlaylistOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPlaylistOrder, order);
  }
}
