/// Utility for parsing YouTube URLs into video IDs and playlist IDs.
///
/// Supports:
///   https://www.youtube.com/watch?v=VIDEO_ID
///   https://youtu.be/VIDEO_ID
///   https://www.youtube.com/shorts/VIDEO_ID
///   https://www.youtube.com/playlist?list=PLAYLIST_ID
///   https://www.youtube.com/watch?v=VIDEO_ID&list=PLAYLIST_ID
class YouTubeUrlParser {
  YouTubeUrlParser._();

  // ─── Video ID extraction ──────────────────────────────────────────────────

  /// Returns the YouTube video ID for any recognised URL format, or `null`.
  static String? extractVideoId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final host = uri.host.replaceFirst('www.', '');

    // youtu.be/VIDEO_ID
    if (host == 'youtu.be') {
      final id = uri.pathSegments.firstOrNull;
      return _validId(id);
    }

    // youtube.com/watch?v=VIDEO_ID
    if (host == 'youtube.com') {
      // /watch?v=
      if (uri.path == '/watch') {
        final id = uri.queryParameters['v'];
        return _validId(id);
      }
      // /shorts/VIDEO_ID
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'shorts') {
        final id = uri.pathSegments[1];
        return _validId(id);
      }
      // /embed/VIDEO_ID
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'embed') {
        final id = uri.pathSegments[1];
        return _validId(id);
      }
      // /v/VIDEO_ID
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'v') {
        final id = uri.pathSegments[1];
        return _validId(id);
      }
    }

    return null;
  }

  // ─── Playlist ID extraction ───────────────────────────────────────────────

  /// Returns the YouTube playlist ID for any recognised playlist URL, or `null`.
  static String? extractPlaylistId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final host = uri.host.replaceFirst('www.', '');
    if (host != 'youtube.com') return null;

    final listId = uri.queryParameters['list'];
    return _validPlaylistId(listId);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// YouTube video IDs are 11 alphanumeric + `-_` characters.
  static bool isValidVideoId(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_\-]{11}$').hasMatch(id);

  /// Playlist IDs start with PL, RD, UU, etc. and are ≥13 chars.
  static bool isValidPlaylistId(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_\-]{13,}$').hasMatch(id);

  static String? _validId(String? id) =>
      isValidVideoId(id) ? id : null;

  static String? _validPlaylistId(String? id) =>
      isValidPlaylistId(id) ? id : null;

  /// Constructs the standard watch URL for a given video ID.
  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  /// Constructs the standard playlist URL for a given playlist ID.
  static String playlistUrl(String playlistId) =>
      'https://www.youtube.com/playlist?list=$playlistId';
}
