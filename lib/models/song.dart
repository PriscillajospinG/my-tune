/// Plain Dart model — no code generation required.
class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final List<int>? albumArtBytes;
  final int durationMs;
  final DateTime dateAdded;

  const Song({
    this.id = 0,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    this.albumArtBytes,
    required this.durationMs,
    required this.dateAdded,
  });

  Duration get duration => Duration(milliseconds: durationMs);
  bool get hasArt => albumArtBytes != null && albumArtBytes!.isNotEmpty;

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    List<int>? albumArtBytes,
    int? durationMs,
    DateTime? dateAdded,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      albumArtBytes: albumArtBytes ?? this.albumArtBytes,
      durationMs: durationMs ?? this.durationMs,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'artist': artist,
        'album': album,
        'filePath': filePath,
        'albumArtBytes': albumArtBytes != null
            ? String.fromCharCodes(albumArtBytes!)
            : null,
        'durationMs': durationMs,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        id: map['id'] as int? ?? 0,
        title: map['title'] as String? ?? 'Unknown',
        artist: map['artist'] as String? ?? 'Unknown Artist',
        album: map['album'] as String? ?? 'Unknown Album',
        filePath: map['filePath'] as String? ?? '',
        albumArtBytes: map['albumArtBytes'] != null
            ? (map['albumArtBytes'] as String).codeUnits
            : null,
        durationMs: map['durationMs'] as int? ?? 0,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(
            map['dateAdded'] as int? ?? 0),
      );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
