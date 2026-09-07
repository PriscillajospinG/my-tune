import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import 'database_service.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return MediaLibraryService(db);
});

// ─── MusicSource abstraction ──────────────────────────────────────────────────
// Designed so a future CloudMusicSource / OnlineMusicSource can be added easily.

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

// ─── MediaLibraryService ──────────────────────────────────────────────────────

class MediaLibraryService {
  final DatabaseService _db;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  MediaLibraryService(this._db);

  static const List<String> _supportedExtensions = [
    'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Query all songs from the device media store (Android / iOS).
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

    final existing = await _db.getAllSongs();
    final existingPaths = existing.map((s) => s.filePath).toSet();

    final imported = <Song>[];
    for (final ds in deviceSongs) {
      final path = ds.data;
      if (path == null || path.isEmpty) continue;

      final ext = ds.fileExtension?.toLowerCase() ?? '';
      if (!_supportedExtensions.contains(ext)) continue;
      if (existingPaths.contains(path)) continue;

      final song = Song(
        title: ds.title.isNotEmpty ? ds.title : _fileNameWithoutExt(path),
        artist: ds.artist ?? 'Unknown Artist',
        album: ds.album ?? 'Unknown Album',
        filePath: path,
        durationMs: ds.duration ?? 0,
        albumArtBytes: null, // Loaded on-demand via fetchArtworkForSong()
        dateAdded: DateTime.now(),
      );

      final savedId = await _db.saveSong(song);
      if (savedId <= 0) continue;

      final savedSong = song.copyWith(id: savedId);
      await _upsertAlbum(savedSong);
      await _upsertArtist(savedSong);
      imported.add(savedSong);
    }
    return imported;
  }

  /// Import songs via file picker (iOS / manual import fallback).
  Future<List<Song>> importSongsFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final existing = await _db.getAllSongs();
    final existingPaths = existing.map((s) => s.filePath).toSet();

    final imported = <Song>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final ext = path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;
      if (existingPaths.contains(path)) continue;

      final song = Song(
        title: _fileNameWithoutExt(path),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        filePath: path,
        durationMs: 0,
        albumArtBytes: null,
        dateAdded: DateTime.now(),
      );

      final savedId = await _db.saveSong(song);
      if (savedId <= 0) continue;

      final savedSong = song.copyWith(id: savedId);
      await _upsertAlbum(savedSong);
      await _upsertArtist(savedSong);
      imported.add(savedSong);
    }
    return imported;
  }

  /// Fetches album artwork bytes using on_audio_query (Android / iOS).
  Future<Uint8List?> fetchArtworkForSong(int songId, {int? albumId}) async {
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
      final audio = await Permission.audio.request();
      if (audio.isGranted) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    // iOS: on_audio_query handles MPMediaLibrary permission internally
    return true;
  }

  Future<void> _upsertAlbum(Song song) async {
    final albums = await _db.getAllAlbums();
    final exists = albums.any(
        (a) => a.name == song.album && a.artist == song.artist);
    if (!exists) {
      await _db.saveAlbum(Album(
        name: song.album,
        artist: song.artist,
      ));
    }
  }

  Future<void> _upsertArtist(Song song) async {
    final artists = await _db.getAllArtists();
    final exists = artists.any((a) => a.name == song.artist);
    if (!exists) {
      await _db.saveArtist(Artist(name: song.artist));
    }
  }

  String _fileNameWithoutExt(String path) {
    final parts = path.split(Platform.pathSeparator);
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }
}
