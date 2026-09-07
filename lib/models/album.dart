class Album {
  final int id;
  final String name;
  final String artist;
  final List<int>? artBytes;

  const Album({
    this.id = 0,
    required this.name,
    required this.artist,
    this.artBytes,
  });

  Album copyWith({int? id, String? name, String? artist, List<int>? artBytes}) =>
      Album(
        id: id ?? this.id,
        name: name ?? this.name,
        artist: artist ?? this.artist,
        artBytes: artBytes ?? this.artBytes,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'artist': artist,
        'artBytes': artBytes != null ? String.fromCharCodes(artBytes!) : null,
      };

  factory Album.fromMap(Map<String, dynamic> map) => Album(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? 'Unknown Album',
        artist: map['artist'] as String? ?? 'Unknown Artist',
        artBytes: map['artBytes'] != null
            ? (map['artBytes'] as String).codeUnits
            : null,
      );
}
