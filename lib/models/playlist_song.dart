import 'package:isar/isar.dart';

part 'playlist_song.g.dart';

/// Join table linking songs to playlists with ordering.
@collection
class PlaylistSong {
  Id id = Isar.autoIncrement;

  @Index()
  late int playlistId;

  @Index()
  late int songId;

  late int position;
}
