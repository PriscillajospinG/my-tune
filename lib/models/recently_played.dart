import 'package:isar/isar.dart';

part 'recently_played.g.dart';

@collection
class RecentlyPlayed {
  Id id = Isar.autoIncrement;

  @Index()
  late int songId;

  late DateTime playedAt;
}
