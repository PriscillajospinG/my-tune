import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import '../services/media_library_service.dart';

export 'playlist_provider.dart'
    show favoriteSongsProvider, favoriteNotifierProvider, FavoriteNotifier;

// ─── Song / Album / Artist streams ───────────────────────────────────────────

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

// ─── Library Notifier ─────────────────────────────────────────────────────────

class LibraryNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getAllSongs();
  }

  /// Import songs — uses file picker on iOS, device media store with file picker fallback on Android
  Future<List<Song>> importSongs() async {
    final mediaService = ref.read(mediaLibraryServiceProvider);
    state = const AsyncValue.loading();
    try {
      List<Song> imported;
      if (Platform.isIOS) {
        imported = await mediaService.importSongsFromPicker();
      } else {
        // Try device MediaStore (best on Android)
        imported = await mediaService.queryDeviceSongs();
        // Fall back to file picker (manual import)
        if (imported.isEmpty) {
          imported = await mediaService.importSongsFromPicker();
        }
      }
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
    await _refresh();
  }

  Future<void> _refresh() async {
    final db = ref.read(databaseServiceProvider);
    state = AsyncValue.data(await db.getAllSongs());
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<Song>>(
  LibraryNotifier.new,
);

// ─── Home data ────────────────────────────────────────────────────────────────

final recentlyPlayedProvider = FutureProvider<List<Song>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getRecentlyPlayed(limit: 10);
});

// ─── Search ───────────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final db = ref.watch(databaseServiceProvider);
  return db.searchSongs(query);
});
