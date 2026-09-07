import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/database_service.dart';
import '../services/media_library_service.dart';

// ─── Songs ────────────────────────────────────────────────────────────────

final songsStreamProvider = StreamProvider<List<Song>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchAllSongs();
});

final albumsStreamProvider = StreamProvider<List<Album>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchAllAlbums();
});

final artistsStreamProvider = StreamProvider<List<Artist>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchAllArtists();
});

// ─── Library Notifier ─────────────────────────────────────────────────────

class LibraryNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getAllSongs();
  }

  /// Import songs via file picker and refresh
  Future<List<Song>> importSongs() async {
    final mediaService = ref.read(mediaLibraryServiceProvider);
    state = const AsyncValue.loading();
    try {
      final imported = await mediaService.importSongsFromPicker();
      final db = ref.read(databaseServiceProvider);
      final all = await db.getAllSongs();
      state = AsyncValue.data(all);
      return imported;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return [];
    }
  }

  Future<void> deleteSong(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteSong(id);
    final all = await db.getAllSongs();
    state = AsyncValue.data(all);
  }

  Future<void> refresh() async {
    final db = ref.read(databaseServiceProvider);
    final all = await db.getAllSongs();
    state = AsyncValue.data(all);
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<Song>>(
  LibraryNotifier.new,
);

// ─── Home data ────────────────────────────────────────────────────────────

final recentlyPlayedProvider = FutureProvider<List<Song>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getRecentlyPlayed(limit: 10);
});

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getFavoriteSongs();
});

// ─── Search ───────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final db = ref.watch(databaseServiceProvider);
  return db.searchSongs(query);
});
