import 'package:isar/isar.dart';

part 'playlist.g.dart';

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  late String name;
  late DateTime createdAt;
  DateTime? updatedAt;
}
