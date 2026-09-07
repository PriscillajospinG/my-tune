import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import 'database_service.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return MediaLibraryService(db);
});

// ─── MusicSource abstraction ────────────────────────────────────────────────
// Designed to allow LocalMusicSource, CloudMusicSource, OnlineMusicSource etc.

abstract class MusicSource {
  Future<List<Song>> fetchSongs();
}

/// Queries the device's native media library (Android MediaStore / iOS MPMediaQuery)
class LocalMusicSource implements MusicSource {
  final MediaLibraryService _service;
  LocalMusicSource(this._service);

  @override
  Future<List<Song>> fetchSongs() => _service.queryDeviceSongs();
}

// ─── MediaLibraryService ────────────────────────────────────────────────────

class MediaLibraryService {
  final DatabaseService _db;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  MediaLibraryService(this._db);

  static const List<String> _supportedExtensions = [
    'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Query all songs from device media store (Android/iOS).
  /// Requests permissions if needed. Returns newly imported songs.
  Future<List<Song>> queryDeviceSongs() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return [];

    final deviceSongs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final imported = <Song>[];
    for (final ds in deviceSongs) {
      if (ds.data == null || ds.data!.isEmpty) continue;

      final ext = ds.fileExtension?.toLowerCase() ?? '';
      if (!_supportedExtensions.contains(ext)) continue;

      // Skip already imported paths
      final existing = await _db.getAllSongs();
      if (existing.any((s) => s.filePath == ds.data)) continue;

      final song = Song()
        ..title = ds.title.isNotEmpty ? ds.title : _fileNameWithoutExt(ds.data!)
        ..artist = ds.artist ?? 'Unknown Artist'
        ..album = ds.album ?? 'Unknown Album'
        ..filePath = ds.data!
        ..durationMs = ds.duration ?? 0
        ..albumArtBytes = null // fetched on-demand via on_audio_query
        ..dateAdded = DateTime.now();

      final id = await _db.saveSong(song);
      song.id = id;

      await _upsertAlbum(song, ds.albumId);
      await _upsertArtist(song);

      imported.add(song);
    }
    return imported;
  }

  /// Import songs via file picker (iOS fallback or cross-platform manual import)
  Future<List<Song>> importSongsFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final imported = <Song>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final ext = path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;

      final existing = await _db.getAllSongs();
      if (existing.any((s) => s.filePath == path)) continue;

      final song = Song()
        ..title = _fileNameWithoutExt(path)
        ..artist = 'Unknown Artist'
        ..album = 'Unknown Album'
        ..filePath = path
        ..durationMs = 0
        ..albumArtBytes = null
        ..dateAdded = DateTime.now();

      final id = await _db.saveSong(song);
      song.id = id;
      await _upsertAlbum(song, null);
      await _upsertArtist(song);
      imported.add(song);
    }
    return imported;
  }

  /// Fetches album artwork bytes for a song using on_audio_query.
  /// Returns null if not available.
  Future<Uint8List?> fetchArtworkForSong(int songId, int? albumId) async {
    try {
      final artwork = await _audioQuery.queryArtwork(
        albumId ?? songId,
        ArtworkType.ALBUM,
        quality: 80,
        size: 400,
      );
      return artwork;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ uses READ_MEDIA_AUDIO; older uses READ_EXTERNAL_STORAGE
      final status = await Permission.audio.request();
      if (status.isGranted) return true;
      // Fallback for older Android
      final storage = await Permission.storage.request();
      return storage.isGranted;
    } else if (Platform.isIOS) {
      // on_audio_query handles iOS MPMediaLibrary permission internally
      return true;
    }
    return true;
  }

  Future<void> _upsertAlbum(Song song, int? deviceAlbumId) async {
    final albums = await _db.getAllAlbums();
    Album? album = albums
        .where((a) => a.name == song.album && a.artist == song.artist)
        .firstOrNull;

    if (album == null) {
      album = Album()
        ..name = song.album
        ..artist = song.artist
        ..artBytes = null
        ..songIds = [song.id];
    } else {
      if (!album.songIds.contains(song.id)) album.songIds.add(song.id);
    }
    await _db.saveAlbum(album);
  }

  Future<void> _upsertArtist(Song song) async {
    final artists = await _db.getAllArtists();
    Artist? artist = artists.where((a) => a.name == song.artist).firstOrNull;

    if (artist == null) {
      artist = Artist()
        ..name = song.artist
        ..songIds = [song.id];
    } else {
      if (!artist.songIds.contains(song.id)) artist.songIds.add(song.id);
    }
    await _db.saveArtist(artist);
  }

  String _fileNameWithoutExt(String path) {
    final parts = path.split(Platform.pathSeparator);
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }
}
