import 'package:isar/isar.dart';

part 'artist.g.dart';

@collection
class Artist {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  List<int> songIds = [];
}
