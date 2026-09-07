class Artist {
  final int id;
  final String name;

  const Artist({this.id = 0, required this.name});

  Map<String, dynamic> toMap() => {'name': name};

  factory Artist.fromMap(Map<String, dynamic> map) => Artist(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? 'Unknown Artist',
      );
}
