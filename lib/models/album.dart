import 'package:isar/isar.dart';

part 'album.g.dart';

@collection
class Album {
  Id id = Isar.autoIncrement;

  late String name;
  late String artist;
  List<byte>? artBytes;

  /// Song IDs belonging to this album
  List<int> songIds = [];
}
