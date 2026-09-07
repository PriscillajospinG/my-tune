import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';

import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import 'database_service.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return MediaLibraryService(db);
});

/// MusicSource abstraction — designed to allow future cloud/online sources
abstract class MusicSource {
  Future<List<Song>> fetchSongs();
}

/// Local file system music source
class LocalMusicSource implements MusicSource {
  final MediaLibraryService _service;
  LocalMusicSource(this._service);

  @override
  Future<List<Song>> fetchSongs() => _service._importViaPicker();
}

class MediaLibraryService {
  final DatabaseService _db;

  MediaLibraryService(this._db);

  static const List<String> _supportedExtensions = [
    'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg',
  ];

  /// Opens the file picker and imports selected audio files into the database.
  /// Returns the newly imported songs.
  Future<List<Song>> importSongsFromPicker() {
    return _importViaPicker();
  }

  Future<List<Song>> _importViaPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final imported = <Song>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final ext = path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;

      // Skip if already imported
      final existing = await _db.getAllSongs();
      if (existing.any((s) => s.filePath == path)) continue;

      final song = await _extractMetadata(path);
      final id = await _db.saveSong(song);
      song.id = id;

      // Update album and artist indexes
      await _upsertAlbum(song);
      await _upsertArtist(song);

      imported.add(song);
    }
    return imported;
  }

  /// Extracts ID3/FLAC metadata from an audio file.
  Future<Song> _extractMetadata(String filePath) async {
    String title = _fileNameWithoutExt(filePath);
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    int durationMs = 0;
    Uint8List? artBytes;

    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      if (metadata.title != null && metadata.title!.isNotEmpty) {
        title = metadata.title!;
      }
      if (metadata.artist != null && metadata.artist!.isNotEmpty) {
        artist = metadata.artist!;
      }
      if (metadata.album != null && metadata.album!.isNotEmpty) {
        album = metadata.album!;
      }
      if (metadata.durationMs != null) {
        durationMs = metadata.durationMs!.toInt();
      }
      if (metadata.picture != null) {
        artBytes = metadata.picture!.data;
      }
    } catch (_) {
      // Fallback to filename if metadata read fails
    }

    // Estimate duration from file size if not available
    if (durationMs == 0) {
      try {
        final fileSize = await File(filePath).length();
        // Rough estimate: 128kbps MP3 ≈ 16 bytes/ms
        durationMs = (fileSize / 16).round().clamp(0, 3600000);
      } catch (_) {}
    }

    return Song()
      ..title = title
      ..artist = artist
      ..album = album
      ..filePath = filePath
      ..albumArtBytes = artBytes
      ..durationMs = durationMs
      ..dateAdded = DateTime.now();
  }

  Future<void> _upsertAlbum(Song song) async {
    final albums = await _db.getAllAlbums();
    Album? album = albums
        .where((a) => a.name == song.album && a.artist == song.artist)
        .firstOrNull;

    if (album == null) {
      album = Album()
        ..name = song.album
        ..artist = song.artist
        ..artBytes = song.albumArtBytes
        ..songIds = [song.id];
    } else {
      if (!album.songIds.contains(song.id)) {
        album.songIds.add(song.id);
      }
      album.artBytes ??= song.albumArtBytes;
    }
    await _db.saveAlbum(album);
  }

  Future<void> _upsertArtist(Song song) async {
    final artists = await _db.getAllArtists();
    Artist? artist =
        artists.where((a) => a.name == song.artist).firstOrNull;

    if (artist == null) {
      artist = Artist()
        ..name = song.artist
        ..songIds = [song.id];
    } else {
      if (!artist.songIds.contains(song.id)) {
        artist.songIds.add(song.id);
      }
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
