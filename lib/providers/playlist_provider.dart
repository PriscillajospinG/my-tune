import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/database_service.dart';

// ─── Playlists ────────────────────────────────────────────────────────────────

final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchAllPlaylists();
});

class PlaylistNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getAllPlaylists();
  }

  Future<void> create(String name) async {
    final db = ref.read(databaseServiceProvider);
    await db.createPlaylist(name);
    await _refresh();
  }

  Future<void> rename(int id, String newName) async {
    final db = ref.read(databaseServiceProvider);
    await db.renamePlaylist(id, newName);
    await _refresh();
  }

  Future<void> delete(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deletePlaylist(id);
    await _refresh();
  }

  Future<void> addSong(int playlistId, int songId) async {
    final db = ref.read(databaseServiceProvider);
    await db.addSongToPlaylist(playlistId, songId);
  }

  Future<void> removeSong(int playlistId, int songId) async {
    final db = ref.read(databaseServiceProvider);
    await db.removeSongFromPlaylist(playlistId, songId);
  }

  Future<List<Song>> getSongsInPlaylist(int playlistId) async {
    final db = ref.read(databaseServiceProvider);
    return db.getSongsInPlaylist(playlistId);
  }

  Future<void> _refresh() async {
    final db = ref.read(databaseServiceProvider);
    state = AsyncValue.data(await db.getAllPlaylists());
  }
}

final playlistProvider =
    AsyncNotifierProvider<PlaylistNotifier, List<Playlist>>(
  PlaylistNotifier.new,
);

// ─── Favorites ────────────────────────────────────────────────────────────────

class FavoriteNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _loadFavorites();
    return {};
  }

  Future<void> _loadFavorites() async {
    final db = ref.read(databaseServiceProvider);
    final ids = await db.getAllFavoriteIds();
    state = ids;
  }

  bool isFavorite(int songId) => state.contains(songId);

  Future<void> toggle(int songId) async {
    final db = ref.read(databaseServiceProvider);
    await db.toggleFavorite(songId);
    if (state.contains(songId)) {
      state = {...state}..remove(songId);
    } else {
      state = {...state, songId};
    }
    // Invalidate home-screen favorites list
    ref.invalidate(favoriteSongsProvider);
  }
}

final favoriteNotifierProvider = NotifierProvider<FavoriteNotifier, Set<int>>(
  FavoriteNotifier.new,
);

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getFavoriteSongs();
});
