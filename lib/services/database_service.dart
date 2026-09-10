import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/youtube_video.dart';
import '../models/media_source_type.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// ─── DatabaseService ─────────────────────────────────────────────────────────

class DatabaseService {
  static Database? _db;

  // Stream controllers for reactive UI updates
  final _songStreamController = StreamController<List<Song>>.broadcast();
  final _albumStreamController = StreamController<List<Album>>.broadcast();
  final _artistStreamController = StreamController<List<Artist>>.broadcast();
  final _playlistStreamController = StreamController<List<Playlist>>.broadcast();
  final _favStreamController = StreamController<List<Song>>.broadcast();
  final _ytVideoStreamController = StreamController<List<YouTubeVideo>>.broadcast();

  // ── Database init ──────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'mytune.db');

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _createYouTubeTables(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        filePath TEXT NOT NULL UNIQUE,
        albumArtBytes TEXT,
        durationMs INTEGER NOT NULL DEFAULT 0,
        dateAdded INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE albums (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        artist TEXT NOT NULL,
        artBytes TEXT,
        UNIQUE(name, artist)
      )
    ''');

    await db.execute('''
      CREATE TABLE artists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistId INTEGER NOT NULL,
        songId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        sourceType TEXT NOT NULL DEFAULT 'local',
        youtubeVideoId TEXT,
        UNIQUE(playlistId, songId),
        FOREIGN KEY(playlistId) REFERENCES playlists(id),
        FOREIGN KEY(songId) REFERENCES songs(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL UNIQUE,
        addedAt INTEGER NOT NULL,
        FOREIGN KEY(songId) REFERENCES songs(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE recently_played (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        playedAt INTEGER NOT NULL,
        sourceType TEXT NOT NULL DEFAULT 'local',
        youtubeVideoId TEXT,
        FOREIGN KEY(songId) REFERENCES songs(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_playlist_songs_playlist ON playlist_songs(playlistId)');
    await db.execute('CREATE INDEX idx_recently_played_time ON recently_played(playedAt DESC)');

    // ── YouTube tables (created fresh on v1 installs too) ─────────────────
    await _createYouTubeTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createYouTubeTables(db);
    }
  }

  Future<void> _createYouTubeTables(Database db) async {
    try {
      await db.execute(
          "ALTER TABLE playlist_songs ADD COLUMN sourceType TEXT NOT NULL DEFAULT 'local'");
    } catch (_) {}
    try {
      await db.execute(
          'ALTER TABLE playlist_songs ADD COLUMN youtubeVideoId TEXT');
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE recently_played ADD COLUMN sourceType TEXT NOT NULL DEFAULT 'local'");
    } catch (_) {}
    try {
      await db.execute(
          'ALTER TABLE recently_played ADD COLUMN youtubeVideoId TEXT');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        youtubeVideoId TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        channelName TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL DEFAULT 0,
        description TEXT DEFAULT '',
        dateAdded INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_youtube_videos_ytid ON youtube_videos(youtubeVideoId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        youtubeVideoId TEXT NOT NULL UNIQUE,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  // ── Songs ─────────────────────────────────────────────────────────────────

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final rows = await db.query('songs', orderBy: 'title ASC');
    return rows.map(Song.fromMap).toList();
  }

  Stream<List<Song>> watchAllSongs() => _songStreamController.stream;

  Future<Song?> getSongById(int id) async {
    final db = await database;
    final rows = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Song.fromMap(rows.first);
  }

  Future<int> saveSong(Song song) async {
    final db = await database;
    final id = await db.insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _notifySongs();
    return id;
  }

  Future<void> deleteSong(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('songs', where: 'id = ?', whereArgs: [id]);
      await txn.delete('favorites', where: 'songId = ?', whereArgs: [id]);
      await txn.delete('recently_played', where: 'songId = ?', whereArgs: [id]);
      await txn.delete('playlist_songs', where: 'songId = ?', whereArgs: [id]);
    });
    await _notifySongs();
  }

  // ── Albums ────────────────────────────────────────────────────────────────

  Future<List<Album>> getAllAlbums() async {
    final db = await database;
    final rows = await db.query('albums', orderBy: 'name ASC');
    return rows.map(Album.fromMap).toList();
  }

  Stream<List<Album>> watchAllAlbums() => _albumStreamController.stream;

  Future<int> saveAlbum(Album album) async {
    final db = await database;
    final id = await db.insert(
      'albums',
      album.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _notifyAlbums();
    return id > 0 ? id : await _getAlbumId(album.name, album.artist);
  }

  Future<int> _getAlbumId(String name, String artist) async {
    final db = await database;
    final rows = await db.query('albums',
        where: 'name = ? AND artist = ?', whereArgs: [name, artist]);
    return rows.isEmpty ? 0 : rows.first['id'] as int;
  }

  // ── Artists ───────────────────────────────────────────────────────────────

  Future<List<Artist>> getAllArtists() async {
    final db = await database;
    final rows = await db.query('artists', orderBy: 'name ASC');
    return rows.map(Artist.fromMap).toList();
  }

  Stream<List<Artist>> watchAllArtists() => _artistStreamController.stream;

  Future<int> saveArtist(Artist artist) async {
    final db = await database;
    final id = await db.insert(
      'artists',
      artist.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _notifyArtists();
    return id;
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final rows = await db.query('playlists', orderBy: 'createdAt ASC');
    return rows.map(Playlist.fromMap).toList();
  }

  Stream<List<Playlist>> watchAllPlaylists() => _playlistStreamController.stream;

  Future<int> createPlaylist(String name) async {
    final db = await database;
    final id = await db.insert('playlists', {
      'name': name,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _notifyPlaylists();
    return id;
  }

  Future<void> renamePlaylist(int id, String newName) async {
    final db = await database;
    await db.update(
      'playlists',
      {'name': newName, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [id]);
      await txn.delete('playlists', where: 'id = ?', whereArgs: [id]);
    });
    await _notifyPlaylists();
  }

  Future<List<Song>> getSongsInPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM songs s
      INNER JOIN playlist_songs ps ON ps.songId = s.id
      WHERE ps.playlistId = ?
      ORDER BY ps.position ASC
    ''', [playlistId]);
    return rows.map(Song.fromMap).toList();
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await database;
    final existing = await db.query('playlist_songs',
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
    if (existing.isNotEmpty) return;

    final maxPos = await db.rawQuery(
        'SELECT MAX(position) as pos FROM playlist_songs WHERE playlistId = ?',
        [playlistId]);
    final pos = (maxPos.first['pos'] as int? ?? -1) + 1;

    await db.insert('playlist_songs',
        {'playlistId': playlistId, 'songId': songId, 'position': pos},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _notifyPlaylists();
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
    await _notifyPlaylists();
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<List<Song>> getFavoriteSongs() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM songs s
      INNER JOIN favorites f ON f.songId = s.id
      ORDER BY f.addedAt DESC
    ''');
    return rows.map(Song.fromMap).toList();
  }

  Stream<List<Song>> watchFavorites() => _favStreamController.stream;

  Future<bool> isFavorite(int songId) async {
    final db = await database;
    final rows = await db.query('favorites',
        where: 'songId = ?', whereArgs: [songId]);
    return rows.isNotEmpty;
  }

  Future<void> toggleFavorite(int songId) async {
    final db = await database;
    final existing = await db.query('favorites',
        where: 'songId = ?', whereArgs: [songId]);
    if (existing.isNotEmpty) {
      await db.delete('favorites', where: 'songId = ?', whereArgs: [songId]);
    } else {
      await db.insert('favorites', {
        'songId': songId,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await _notifyFavs();
  }

  Future<Set<int>> getAllFavoriteIds() async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['songId']);
    return rows.map((r) => r['songId'] as int).toSet();
  }

  // ── Recently Played ───────────────────────────────────────────────────────

  Future<List<Song>> getRecentlyPlayed({int limit = 20}) async {
    final db = await database;
    // Distinct songIds ordered by most recent play, then look up songs
    final rows = await db.rawQuery('''
      SELECT s.*, MAX(rp.playedAt) as lastPlayed
      FROM songs s
      INNER JOIN recently_played rp ON rp.songId = s.id
      GROUP BY s.id
      ORDER BY lastPlayed DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Song.fromMap).toList();
  }

  Future<void> recordPlay(int songId) async {
    final db = await database;
    await db.insert('recently_played', {
      'songId': songId,
      'playedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Prune old records (keep max 500)
    await db.execute('''
      DELETE FROM recently_played
      WHERE id NOT IN (
        SELECT id FROM recently_played ORDER BY playedAt DESC LIMIT 500
      )
    ''');
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return getAllSongs();
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final rows = await db.rawQuery('''
      SELECT * FROM songs
      WHERE LOWER(title) LIKE ? OR LOWER(artist) LIKE ? OR LOWER(album) LIKE ?
      ORDER BY title ASC
    ''', [q, q, q]);
    return rows.map(Song.fromMap).toList();
  }

  // ── DB info ───────────────────────────────────────────────────────────────

  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'mytune.db');
  }

  // ── Stream notifications ──────────────────────────────────────────────────

  Future<void> _notifySongs() async {
    final songs = await getAllSongs();
    if (!_songStreamController.isClosed) _songStreamController.add(songs);
  }

  Future<void> _notifyAlbums() async {
    final albums = await getAllAlbums();
    if (!_albumStreamController.isClosed) _albumStreamController.add(albums);
  }

  Future<void> _notifyArtists() async {
    final artists = await getAllArtists();
    if (!_artistStreamController.isClosed) _artistStreamController.add(artists);
  }

  Future<void> _notifyPlaylists() async {
    final playlists = await getAllPlaylists();
    if (!_playlistStreamController.isClosed) _playlistStreamController.add(playlists);
  }

  Future<void> _notifyFavs() async {
    if (!_favStreamController.isClosed) {
      final favs = await getFavoriteSongs();
      _favStreamController.add(favs);
    }
  }

  void dispose() {
    _songStreamController.close();
    _albumStreamController.close();
    _artistStreamController.close();
    _playlistStreamController.close();
    _favStreamController.close();
    _ytVideoStreamController.close();
  }

  // ── YouTube Videos ────────────────────────────────────────────────────────

  Future<List<YouTubeVideo>> getAllYouTubeVideos() async {
    final db = await database;
    final rows = await db.query('youtube_videos', orderBy: 'dateAdded DESC');
    return rows.map(YouTubeVideo.fromMap).toList();
  }

  Stream<List<YouTubeVideo>> watchAllYouTubeVideos() =>
      _ytVideoStreamController.stream;

  Future<YouTubeVideo?> getYouTubeVideoById(String ytId) async {
    final db = await database;
    final rows = await db.query('youtube_videos',
        where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    if (rows.isEmpty) return null;
    return YouTubeVideo.fromMap(rows.first);
  }

  Future<int> saveYouTubeVideo(YouTubeVideo video) async {
    final db = await database;
    final id = await db.insert(
      'youtube_videos',
      video.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyYtVideos();
    return id;
  }

  Future<void> deleteYouTubeVideo(String ytId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('youtube_videos',
          where: 'youtubeVideoId = ?', whereArgs: [ytId]);
      await txn.delete('youtube_favorites',
          where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    });
    await _notifyYtVideos();
  }

  Future<bool> isYouTubeVideoSaved(String ytId) async {
    final db = await database;
    final rows = await db.query('youtube_videos',
        columns: ['id'], where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    return rows.isNotEmpty;
  }

  // ── YouTube Favorites ─────────────────────────────────────────────────────

  Future<bool> isYouTubeFavorite(String ytId) async {
    final db = await database;
    final rows = await db.query('youtube_favorites',
        where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    return rows.isNotEmpty;
  }

  Future<void> toggleYouTubeFavorite(String ytId) async {
    final db = await database;
    final existing = await db.query('youtube_favorites',
        where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    if (existing.isNotEmpty) {
      await db.delete('youtube_favorites',
          where: 'youtubeVideoId = ?', whereArgs: [ytId]);
    } else {
      await db.insert('youtube_favorites', {
        'youtubeVideoId': ytId,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Set<String>> getAllYouTubeFavoriteIds() async {
    final db = await database;
    final rows = await db.query('youtube_favorites', columns: ['youtubeVideoId']);
    return rows.map((r) => r['youtubeVideoId'] as String).toSet();
  }

  Future<List<YouTubeVideo>> getFavoriteYouTubeVideos() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT yv.* FROM youtube_videos yv
      INNER JOIN youtube_favorites yf ON yf.youtubeVideoId = yv.youtubeVideoId
      ORDER BY yf.addedAt DESC
    ''');
    return rows.map(YouTubeVideo.fromMap).toList();
  }

  // ── YouTube in Playlists ──────────────────────────────────────────────────

  Future<void> addYouTubeVideoToPlaylist(
      int playlistId, String ytVideoId) async {
    final db = await database;
    final existing = await db.query('playlist_songs',
        where: 'playlistId = ? AND youtubeVideoId = ?',
        whereArgs: [playlistId, ytVideoId]);
    if (existing.isNotEmpty) return;

    final maxPos = await db.rawQuery(
        'SELECT MAX(position) as pos FROM playlist_songs WHERE playlistId = ?',
        [playlistId]);
    final pos = (maxPos.first['pos'] as int? ?? -1) + 1;

    await db.insert(
        'playlist_songs',
        {
          'playlistId': playlistId,
          'songId': 0, // unused for youtube items
          'youtubeVideoId': ytVideoId,
          'sourceType': MediaSourceType.youtube.value,
          'position': pos,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _notifyPlaylists();
  }

  Future<List<YouTubeVideo>> getYouTubeVideosInPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT yv.* FROM youtube_videos yv
      INNER JOIN playlist_songs ps
        ON ps.youtubeVideoId = yv.youtubeVideoId
      WHERE ps.playlistId = ? AND ps.sourceType = 'youtube'
      ORDER BY ps.position ASC
    ''', [playlistId]);
    return rows.map(YouTubeVideo.fromMap).toList();
  }

  Future<void> removeYouTubeVideoFromPlaylist(
      int playlistId, String ytVideoId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlistId = ? AND youtubeVideoId = ?',
        whereArgs: [playlistId, ytVideoId]);
    await _notifyPlaylists();
  }

  // ── YouTube in Recently Played ────────────────────────────────────────────

  Future<void> recordYouTubePlay(String ytVideoId) async {
    final db = await database;
    await db.insert('recently_played', {
      'songId': 0, // unused for youtube items
      'youtubeVideoId': ytVideoId,
      'sourceType': MediaSourceType.youtube.value,
      'playedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Prune old records
    await db.execute('''
      DELETE FROM recently_played
      WHERE id NOT IN (
        SELECT id FROM recently_played ORDER BY playedAt DESC LIMIT 500
      )
    ''');
  }

  Future<List<YouTubeVideo>> getRecentlyPlayedYouTubeVideos(
      {int limit = 20}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT yv.*, MAX(rp.playedAt) as lastPlayed
      FROM youtube_videos yv
      INNER JOIN recently_played rp ON rp.youtubeVideoId = yv.youtubeVideoId
      WHERE rp.sourceType = 'youtube'
      GROUP BY yv.youtubeVideoId
      ORDER BY lastPlayed DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(YouTubeVideo.fromMap).toList();
  }

  // ── YouTube stream notification ───────────────────────────────────────────

  Future<void> _notifyYtVideos() async {
    final videos = await getAllYouTubeVideos();
    if (!_ytVideoStreamController.isClosed) {
      _ytVideoStreamController.add(videos);
    }
  }
}
