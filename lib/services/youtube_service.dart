import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/youtube_video.dart';

// ─── API key — injected via --dart-define at build time ───────────────────────
// Never commit your API key to source control.
// Usage:  flutter run --dart-define=YOUTUBE_API_KEY=YOUR_KEY
const _apiKey =
    String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');

// ─── Provider ─────────────────────────────────────────────────────────────────
final youTubeServiceProvider = Provider<YouTubeService>((ref) {
  return YouTubeService();
});

// ─── Custom exceptions ────────────────────────────────────────────────────────

class YouTubeApiException implements Exception {
  final String message;
  final YouTubeApiError type;
  const YouTubeApiException(this.message, this.type);

  @override
  String toString() => 'YouTubeApiException($type): $message';
}

enum YouTubeApiError {
  missingApiKey,
  quotaExceeded,
  networkError,
  timeout,
  notFound,
  restricted,
  unknown,
}

// ─── Service ──────────────────────────────────────────────────────────────────

class YouTubeService {
  static const _base = 'https://www.googleapis.com/youtube/v3';
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;

  YouTubeService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Search YouTube for videos matching [query].
  /// Returns up to [maxResults] results (max 50 per API call).
  Future<List<YouTubeVideo>> searchVideos(
    String query, {
    int maxResults = 20,
  }) async {
    _requireKey();
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'part': 'snippet',
      'q': query.trim(),
      'type': 'video',
      'maxResults': '$maxResults',
      'safeSearch': 'moderate',
      'key': _apiKey,
    });

    final json = await _get(uri);
    final items = (json['items'] as List<dynamic>? ?? []);

    // Fetch full details (including duration) in a second call
    final ids = items
        .map((e) => (e['id'] as Map<String, dynamic>)['videoId'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];

    return getVideoDetails(ids);
  }

  /// Fetch full video details for a list of video IDs.
  Future<List<YouTubeVideo>> getVideoDetails(List<String> ids) async {
    _requireKey();
    if (ids.isEmpty) return [];

    final uri = Uri.parse('$_base/videos').replace(queryParameters: {
      'part': 'snippet,contentDetails',
      'id': ids.join(','),
      'key': _apiKey,
    });

    final json = await _get(uri);
    final items = (json['items'] as List<dynamic>? ?? []);
    return items
        .map((e) =>
            YouTubeVideo.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single video's details by video ID.
  Future<YouTubeVideo?> getVideoDetail(String videoId) async {
    final results = await getVideoDetails([videoId]);
    return results.firstOrNull;
  }

  /// Fetch playlist metadata (name, thumbnail, item count).
  Future<Map<String, dynamic>?> getPlaylistDetails(String playlistId) async {
    _requireKey();

    final uri = Uri.parse('$_base/playlists').replace(queryParameters: {
      'part': 'snippet,contentDetails',
      'id': playlistId,
      'key': _apiKey,
    });

    final json = await _get(uri);
    final items = json['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return null;

    final item = items.first as Map<String, dynamic>;
    final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
    final content = item['contentDetails'] as Map<String, dynamic>? ?? {};
    final thumbs = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    final thumb = (thumbs['high'] ?? thumbs['medium'] ?? thumbs['default'])
        as Map<String, dynamic>?;

    return {
      'playlistId': playlistId,
      'title': snippet['title'] ?? 'Unknown Playlist',
      'channelTitle': snippet['channelTitle'] ?? '',
      'description': snippet['description'] ?? '',
      'thumbnailUrl': thumb?['url'] ?? '',
      'itemCount': content['itemCount'] ?? 0,
    };
  }

  /// Fetch all video IDs + metadata from a playlist.
  /// Automatically follows nextPageToken to get all pages.
  Future<List<YouTubeVideo>> getPlaylistItems(String playlistId) async {
    _requireKey();

    final videoIds = <String>[];
    String? pageToken;

    do {
      final params = <String, String>{
        'part': 'contentDetails',
        'playlistId': playlistId,
        'maxResults': '50',
        'key': _apiKey,
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri = Uri.parse('$_base/playlistItems')
          .replace(queryParameters: params);
      final json = await _get(uri);

      final items = json['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final cd =
            (item as Map<String, dynamic>)['contentDetails']
                as Map<String, dynamic>?;
        final vid = cd?['videoId'] as String?;
        if (vid != null) videoIds.add(vid);
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null && videoIds.length < 200);

    // Batch fetch details in groups of 50 (API limit per call)
    final results = <YouTubeVideo>[];
    for (var i = 0; i < videoIds.length; i += 50) {
      final batch = videoIds.sublist(
          i, i + 50 > videoIds.length ? videoIds.length : i + 50);
      results.addAll(await getVideoDetails(batch));
    }
    return results;
  }

  // ─── HTTP helper ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_timeout);
      return _parseResponse(response);
    } on TimeoutException {
      throw const YouTubeApiException(
          'Request timed out', YouTubeApiError.timeout);
    } on SocketException {
      throw const YouTubeApiException(
          'No internet connection', YouTubeApiError.networkError);
    } on YouTubeApiException {
      rethrow;
    } catch (e) {
      throw YouTubeApiException('$e', YouTubeApiError.unknown);
    }
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // Try to extract the error reason from Google's error envelope
    String? reason;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors =
          ((body['error'] as Map<String, dynamic>?)?['errors'] as List?)
              ?.cast<Map<String, dynamic>>();
      reason = errors?.first['reason'] as String?;
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        throw YouTubeApiException(
            'Bad request: ${response.body}', YouTubeApiError.unknown);
      case 403:
        if (reason == 'quotaExceeded' ||
            reason == 'dailyLimitExceeded') {
          throw const YouTubeApiException(
              'YouTube API quota exceeded', YouTubeApiError.quotaExceeded);
        }
        if (reason == 'forbidden' || reason == 'accessNotConfigured') {
          throw YouTubeApiException(
              'Access denied: $reason', YouTubeApiError.restricted);
        }
        throw YouTubeApiException(
            'Forbidden (${response.statusCode}): ${response.body}',
            YouTubeApiError.restricted);
      case 404:
        throw const YouTubeApiException(
            'Resource not found', YouTubeApiError.notFound);
      default:
        throw YouTubeApiException(
            'HTTP ${response.statusCode}', YouTubeApiError.unknown);
    }
  }

  void _requireKey() {
    if (_apiKey.isEmpty) {
      throw const YouTubeApiException(
        'YouTube API key not configured. '
        'Pass --dart-define=YOUTUBE_API_KEY=YOUR_KEY when running.',
        YouTubeApiError.missingApiKey,
      );
    }
  }
}
