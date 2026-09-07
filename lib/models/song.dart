import 'package:isar/isar.dart';

part 'song.g.dart';

@collection
class Song {
  Id id = Isar.autoIncrement;

  late String title;
  late String artist;
  late String album;
  late String filePath;

  /// Album art stored as raw bytes (extracted from ID3 tags or null)
  List<byte>? albumArtBytes;

  /// Duration in milliseconds
  late int durationMs;

  late DateTime dateAdded;

  @ignore
  Duration get duration => Duration(milliseconds: durationMs);

  @ignore
  bool get hasArt => albumArtBytes != null && albumArtBytes!.isNotEmpty;
}
