import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'services/audio_player_service.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize background audio support
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mytune.mytune.audio',
    androidNotificationChannelName: 'MyTune Audio',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    preloadArtwork: true,
  );

  // Create DatabaseService (sqflite opens lazily — no async init needed here)
  final dbService = DatabaseService();

  // Create and register the AudioPlayerService with audio_service
  final audioHandler = await AudioService.init<AudioPlayerService>(
    builder: () => AudioPlayerService(dbService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mytune.mytune.audio',
      androidNotificationChannelName: 'MyTune Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      artDownscaleHeight: 300,
      artDownscaleWidth: 300,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        audioPlayerServiceProvider.overrideWithValue(audioHandler),
      ],
      child: const MyTuneApp(),
    ),
  );
}
