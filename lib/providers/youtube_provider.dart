import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/youtube_video.dart';
import '../repositories/youtube_repository.dart';
import '../services/database_service.dart';
import '../services/youtube_service.dart';

// ─── Search mode selector ─────────────────────────────────────────────────────

enum SearchMode { library, youtube }

final searchModeProvider = StateProvider<SearchMode>((ref) => SearchMode.library);

// ─── YouTube search state ─────────────────────────────────────────────────────

final youtubeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Debounced YouTube search results.
/// Only fires an API call after [_debounce] ms of inactivity.
final youtubeSearchProvider =
    AsyncNotifierProvider<YouTubeSearchNotifier, List<YouTubeVideo>>(
  YouTubeSearchNotifier.new,
);

class YouTubeSearchNotifier extends AsyncNotifier<List<YouTubeVideo>> {
  static const _debounce = Duration(milliseconds: 500);
  Timer? _debounceTimer;

  @override
  Future<List<YouTubeVideo>> build() async {
    final query = ref.watch(youtubeSearchQueryProvider);
    if (query.trim().isEmpty) return [];

    // Debounce: cancel any pending search and schedule a new one
    _debounceTimer?.cancel();
    final completer = Completer<List<YouTubeVideo>>();
    _debounceTimer = Timer(_debounce, () async {
      if (!completer.isCompleted) {
        final result = await ref
            .read(youTubeRepositoryProvider)
            .search(query);
        switch (result) {
          case YouTubeSuccess<List<YouTubeVideo>>(:final data):
            completer.complete(data);
          case YouTubeError<List<YouTubeVideo>>():
            completer.complete([]);
        }
      }
    });
    return completer.future;
  }

  /// Trigger a fresh search bypassing debounce (e.g., on submit).
  Future<void> searchNow(String query) async {
    _debounceTimer?.cancel();
    state = const AsyncValue.loading();
    final repo = ref.read(youTubeRepositoryProvider);
    final result = await repo.search(query);
    switch (result) {
      case YouTubeSuccess<List<YouTubeVideo>>(:final data):
        state = AsyncValue.data(data);
      case YouTubeError<List<YouTubeVideo>>(:final message, :final type):
        state = AsyncValue.error(
            YouTubeApiException(message, type), StackTrace.current);
    }
  }
}

// ─── YouTube search error state (human-readable) ──────────────────────────────

final youtubeSearchErrorProvider = Provider<String?>((ref) {
  final search = ref.watch(youtubeSearchProvider);
  if (!search.hasError) return null;
  final err = search.error;
  if (err is YouTubeApiException) {
    return switch (err.type) {
      YouTubeApiError.missingApiKey =>
        'YouTube API key not configured.',
      YouTubeApiError.quotaExceeded =>
        'YouTube search limit reached. Try again tomorrow.',
      YouTubeApiError.networkError =>
        'No internet connection. YouTube search requires internet.',
      YouTubeApiError.timeout => 'Request timed out. Please try again.',
      YouTubeApiError.notFound => 'Content not found.',
      YouTubeApiError.restricted =>
        'This content is restricted in your region.',
      YouTubeApiError.unknown => 'Unable to search YouTube right now.',
    };
  }
  return 'Unable to search YouTube right now.';
});

// ─── Saved YouTube videos ─────────────────────────────────────────────────────

final savedYouTubeVideosProvider =
    StreamProvider<List<YouTubeVideo>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchAllYouTubeVideos();
});

// ─── YouTube favorites ────────────────────────────────────────────────────────

final youtubeFavoriteNotifierProvider =
    NotifierProvider<YouTubeFavoriteNotifier, Set<String>>(
  YouTubeFavoriteNotifier.new,
);

class YouTubeFavoriteNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final db = ref.read(databaseServiceProvider);
    final ids = await db.getAllYouTubeFavoriteIds();
    state = ids;
  }

  bool isFavorite(String ytId) => state.contains(ytId);

  Future<void> toggle(String ytId) async {
    final db = ref.read(databaseServiceProvider);
    await db.toggleYouTubeFavorite(ytId);
    if (state.contains(ytId)) {
      state = {...state}..remove(ytId);
    } else {
      state = {...state, ytId};
    }
    ref.invalidate(youtubeFavoriteSongsProvider);
  }
}

final youtubeFavoriteSongsProvider =
    FutureProvider<List<YouTubeVideo>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getFavoriteYouTubeVideos();
});

// ─── YouTube playlist helpers ─────────────────────────────────────────────────

final youtubeVideosInPlaylistProvider =
    FutureProvider.family<List<YouTubeVideo>, int>((ref, playlistId) {
  final db = ref.watch(databaseServiceProvider);
  return db.getYouTubeVideosInPlaylist(playlistId);
});

// ─── Recently played YouTube ──────────────────────────────────────────────────

final recentlyPlayedYouTubeProvider =
    FutureProvider<List<YouTubeVideo>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getRecentlyPlayedYouTubeVideos(limit: 10);
});

// ─── Save / unsave a video ────────────────────────────────────────────────────

final saveYouTubeVideoProvider =
    Provider<Future<void> Function(YouTubeVideo)>((ref) {
  return (video) async {
    final db = ref.read(databaseServiceProvider);
    await db.saveYouTubeVideo(video);
  };
});
