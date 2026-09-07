class Playlist {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Playlist({
    this.id = 0,
    required this.name,
    required this.createdAt,
    this.updatedAt,
  });

  Playlist copyWith({int? id, String? name, DateTime? updatedAt}) => Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? 'Playlist',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int? ?? 0),
        updatedAt: map['updatedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
            : null,
      );
}
