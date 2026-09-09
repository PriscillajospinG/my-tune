import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/youtube_video.dart';
import '../services/youtube_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final youTubeRepositoryProvider = Provider<YouTubeRepository>((ref) {
  final service = ref.watch(youTubeServiceProvider);
  return YouTubeRepository(service);
});

// ─── Cache entry ──────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  final Duration ttl;

  _CacheEntry(this.data, {this.ttl = const Duration(minutes: 15)})
      : fetchedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(fetchedAt) > ttl;
}

// ─── Result wrapper ───────────────────────────────────────────────────────────

/// Clean result type so the UI never has to catch exceptions.
sealed class YouTubeResult<T> {
  const YouTubeResult();
}

class YouTubeSuccess<T> extends YouTubeResult<T> {
  final T data;
  const YouTubeSuccess(this.data);
}

class YouTubeError<T> extends YouTubeResult<T> {
  final String message;
  final YouTubeApiError type;
  const YouTubeError(this.message, this.type);
}

// ─── Repository ───────────────────────────────────────────────────────────────

class YouTubeRepository {
  final YouTubeService _service;

  /// In-memory search cache keyed by "query:maxResults"
  final _searchCache = <String, _CacheEntry<List<YouTubeVideo>>>{};

  /// In-memory video detail cache keyed by video ID
  final _detailCache = <String, _CacheEntry<YouTubeVideo>>{};

  YouTubeRepository(this._service);

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<YouTubeResult<List<YouTubeVideo>>> search(
    String query, {
    int maxResults = 20,
  }) async {
    if (query.trim().isEmpty) {
      return const YouTubeSuccess([]);
    }

    final key = '${query.trim().toLowerCase()}:$maxResults';
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) {
      return YouTubeSuccess(cached.data);
    }

    return _wrap(() async {
      final results = await _service.searchVideos(query, maxResults: maxResults);
      _searchCache[key] = _CacheEntry(results);
      // Also seed the detail cache
      for (final v in results) {
        _detailCache[v.youtubeVideoId] = _CacheEntry(v,
            ttl: const Duration(minutes: 30));
      }
      return results;
    });
  }

  // ─── Video detail ─────────────────────────────────────────────────────────

  Future<YouTubeResult<YouTubeVideo?>> getVideoDetail(String videoId) async {
    final cached = _detailCache[videoId];
    if (cached != null && !cached.isExpired) {
      return YouTubeSuccess(cached.data);
    }

    return _wrap(() async {
      final video = await _service.getVideoDetail(videoId);
      if (video != null) {
        _detailCache[videoId] =
            _CacheEntry(video, ttl: const Duration(minutes: 30));
      }
      return video;
    });
  }

  // ─── Playlist ─────────────────────────────────────────────────────────────

  Future<YouTubeResult<Map<String, dynamic>?>> getPlaylistDetails(
      String playlistId) async {
    return _wrap(() => _service.getPlaylistDetails(playlistId));
  }

  Future<YouTubeResult<List<YouTubeVideo>>> getPlaylistItems(
      String playlistId) async {
    return _wrap(() => _service.getPlaylistItems(playlistId));
  }

  // ─── Cache management ─────────────────────────────────────────────────────

  void clearSearchCache() => _searchCache.clear();

  void clearAllCache() {
    _searchCache.clear();
    _detailCache.clear();
  }

  // ─── Error-normalising wrapper ────────────────────────────────────────────

  Future<YouTubeResult<T>> _wrap<T>(Future<T> Function() call) async {
    try {
      return YouTubeSuccess(await call());
    } on YouTubeApiException catch (e) {
      return YouTubeError(e.message, e.type);
    } catch (e) {
      return YouTubeError('$e', YouTubeApiError.unknown);
    }
  }
}
