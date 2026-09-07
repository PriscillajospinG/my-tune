import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/playlist_song.dart';
import '../models/favorite.dart';
import '../models/recently_played.dart';

/// Riverpod provider for the Isar instance (overridden in main.dart)
final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());

/// Provides the DatabaseService singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final isar = ref.watch(isarProvider);
  return DatabaseService(isar);
});

class DatabaseService {
  final Isar _isar;

  DatabaseService(this._isar);

  // ─── Songs ───────────────────────────────────────────────────────

  Future<List<Song>> getAllSongs() async {
    return _isar.songs.where().sortByTitle().findAll();
  }

  Stream<List<Song>> watchAllSongs() {
    return _isar.songs.where().sortByTitle().watch(fireImmediately: true);
  }

  Future<Song?> getSongById(int id) async {
    return _isar.songs.get(id);
  }

  Future<int> saveSong(Song song) async {
    return _isar.writeTxn(() => _isar.songs.put(song));
  }

  Future<void> deleteSong(int id) async {
    await _isar.writeTxn(() async {
      await _isar.songs.delete(id);
      // Cascade: remove favorites, recents, playlist entries
      final favs = await _isar.favorites.filter().songIdEqualTo(id).findAll();
      for (final f in favs) {
        await _isar.favorites.delete(f.id);
      }
      final recents = await _isar.recentlyPlayeds.filter().songIdEqualTo(id).findAll();
      for (final r in recents) {
        await _isar.recentlyPlayeds.delete(r.id);
      }
      final ps = await _isar.playlistSongs.filter().songIdEqualTo(id).findAll();
      for (final p in ps) {
        await _isar.playlistSongs.delete(p.id);
      }
    });
  }

  // ─── Albums ──────────────────────────────────────────────────────

  Future<List<Album>> getAllAlbums() async {
    return _isar.albums.where().sortByName().findAll();
  }

  Stream<List<Album>> watchAllAlbums() {
    return _isar.albums.where().sortByName().watch(fireImmediately: true);
  }

  Future<int> saveAlbum(Album album) async {
    return _isar.writeTxn(() => _isar.albums.put(album));
  }

  // ─── Artists ─────────────────────────────────────────────────────

  Future<List<Artist>> getAllArtists() async {
    return _isar.artists.where().sortByName().findAll();
  }

  Stream<List<Artist>> watchAllArtists() {
    return _isar.artists.where().sortByName().watch(fireImmediately: true);
  }

  Future<int> saveArtist(Artist artist) async {
    return _isar.writeTxn(() => _isar.artists.put(artist));
  }

  // ─── Playlists ───────────────────────────────────────────────────

  Future<List<Playlist>> getAllPlaylists() async {
    return _isar.playlists.where().findAll();
  }

  Stream<List<Playlist>> watchAllPlaylists() {
    return _isar.playlists.where().watch(fireImmediately: true);
  }

  Future<int> createPlaylist(String name) async {
    final playlist = Playlist()
      ..name = name
      ..createdAt = DateTime.now();
    return _isar.writeTxn(() => _isar.playlists.put(playlist));
  }

  Future<void> renamePlaylist(int id, String newName) async {
    final playlist = await _isar.playlists.get(id);
    if (playlist != null) {
      playlist.name = newName;
      playlist.updatedAt = DateTime.now();
      await _isar.writeTxn(() => _isar.playlists.put(playlist));
    }
  }

  Future<void> deletePlaylist(int id) async {
    await _isar.writeTxn(() async {
      await _isar.playlists.delete(id);
      final entries = await _isar.playlistSongs.filter().playlistIdEqualTo(id).findAll();
      for (final e in entries) {
        await _isar.playlistSongs.delete(e.id);
      }
    });
  }

  Future<List<Song>> getSongsInPlaylist(int playlistId) async {
    final entries = await _isar.playlistSongs
        .filter()
        .playlistIdEqualTo(playlistId)
        .sortByPosition()
        .findAll();
    final songs = <Song>[];
    for (final e in entries) {
      final song = await _isar.songs.get(e.songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    // Check if already in playlist
    final existing = await _isar.playlistSongs
        .filter()
        .playlistIdEqualTo(playlistId)
        .songIdEqualTo(songId)
        .findFirst();
    if (existing != null) return;

    final maxPos = await _isar.playlistSongs
        .filter()
        .playlistIdEqualTo(playlistId)
        .sortByPositionDesc()
        .findFirst();
    final pos = (maxPos?.position ?? -1) + 1;

    final ps = PlaylistSong()
      ..playlistId = playlistId
      ..songId = songId
      ..position = pos;

    await _isar.writeTxn(() => _isar.playlistSongs.put(ps));

    // Update playlist timestamp
    final playlist = await _isar.playlists.get(playlistId);
    if (playlist != null) {
      playlist.updatedAt = DateTime.now();
      await _isar.writeTxn(() => _isar.playlists.put(playlist));
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final entries = await _isar.playlistSongs
        .filter()
        .playlistIdEqualTo(playlistId)
        .songIdEqualTo(songId)
        .findAll();
    await _isar.writeTxn(() async {
      for (final e in entries) {
        await _isar.playlistSongs.delete(e.id);
      }
    });
  }

  // ─── Favorites ───────────────────────────────────────────────────

  Future<List<Song>> getFavoriteSongs() async {
    final favs = await _isar.favorites.where().sortByAddedAtDesc().findAll();
    final songs = <Song>[];
    for (final f in favs) {
      final s = await _isar.songs.get(f.songId);
      if (s != null) songs.add(s);
    }
    return songs;
  }

  Stream<List<Favorite>> watchFavorites() {
    return _isar.favorites.where().watch(fireImmediately: true);
  }

  Future<bool> isFavorite(int songId) async {
    return _isar.favorites.filter().songIdEqualTo(songId).isNotEmpty();
  }

  Future<void> toggleFavorite(int songId) async {
    final existing = await _isar.favorites.filter().songIdEqualTo(songId).findFirst();
    if (existing != null) {
      await _isar.writeTxn(() => _isar.favorites.delete(existing.id));
    } else {
      final fav = Favorite()
        ..songId = songId
        ..addedAt = DateTime.now();
      await _isar.writeTxn(() => _isar.favorites.put(fav));
    }
  }

  // ─── Recently Played ─────────────────────────────────────────────

  Future<List<Song>> getRecentlyPlayed({int limit = 20}) async {
    final recents = await _isar.recentlyPlayeds
        .where()
        .sortByPlayedAtDesc()
        .limit(limit)
        .findAll();

    final seen = <int>{};
    final songs = <Song>[];
    for (final r in recents) {
      if (seen.contains(r.songId)) continue;
      seen.add(r.songId);
      final s = await _isar.songs.get(r.songId);
      if (s != null) songs.add(s);
    }
    return songs;
  }

  Future<void> recordPlay(int songId) async {
    final rec = RecentlyPlayed()
      ..songId = songId
      ..playedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.recentlyPlayeds.put(rec));

    // Keep only the last 200 records total to avoid unbounded growth
    final all = await _isar.recentlyPlayeds.where().sortByPlayedAtDesc().findAll();
    if (all.length > 200) {
      final toDelete = all.sublist(200);
      await _isar.writeTxn(() async {
        for (final r in toDelete) {
          await _isar.recentlyPlayeds.delete(r.id);
        }
      });
    }
  }

  // ─── Search ──────────────────────────────────────────────────────

  Future<List<Song>> searchSongs(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return getAllSongs();
    final all = await _isar.songs.where().findAll();
    return all.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }
}
