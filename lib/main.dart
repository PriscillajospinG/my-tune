import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'models/song.dart';
import 'models/album.dart';
import 'models/artist.dart';
import 'models/playlist.dart';
import 'models/playlist_song.dart';
import 'models/favorite.dart';
import 'models/recently_played.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for phone-first experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize just_audio_background for background playback
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mytune.mytune.audio',
    androidNotificationChannelName: 'MyTune Audio',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    androidNotificationClickOpensApp: true,
    preloadArtwork: true,
  );

  // Open Isar database
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      SongSchema,
      AlbumSchema,
      ArtistSchema,
      PlaylistSchema,
      PlaylistSongSchema,
      FavoriteSchema,
      RecentlyPlayedSchema,
    ],
    directory: dir.path,
    name: 'mytune_db',
  );

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const MyTuneApp(),
    ),
  );
}
