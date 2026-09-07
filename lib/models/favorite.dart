import 'package:isar/isar.dart';

part 'favorite.g.dart';

@collection
class Favorite {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int songId;

  late DateTime addedAt;
}
