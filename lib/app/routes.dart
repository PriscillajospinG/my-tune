import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/youtube_video.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/now_playing/now_playing_screen.dart';
import '../screens/playlist/playlist_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/youtube/youtube_details_screen.dart';
import '../screens/youtube/youtube_playlist_import_screen.dart';
import '../widgets/bottom_navigation.dart';

// Shell route key — used by bottom nav to maintain state
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: '/playlists',
            name: 'playlists',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlaylistScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/now-playing',
        name: 'now-playing',
        builder: (context, state) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/youtube/import',
        name: 'youtube-import',
        builder: (context, state) => const YouTubePlaylistImportScreen(),
      ),
      GoRoute(
        path: '/youtube/details',
        name: 'youtube-details',
        builder: (context, state) {
          final video = state.extra as YouTubeVideo;
          return YouTubeDetailsScreen(video: video);
        },
      ),
      GoRoute(
        path: '/youtube/:videoId',
        name: 'youtube-video',
        builder: (context, state) {
          final video = state.extra as YouTubeVideo?;
          final videoId = state.pathParameters['videoId'] ?? '';
          return YouTubeDetailsScreen(
            video: video ??
                YouTubeVideo(
                  youtubeVideoId: videoId,
                  title: 'YouTube Video',
                  channelName: '',
                  thumbnailUrl:
                      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  dateAdded: DateTime.now(),
                ),
          );
        },
      ),
    ],
  );
}
