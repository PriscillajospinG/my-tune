/// A YouTube video reference saved to MyTune.
///
/// Only metadata is stored — no audio or video bytes are ever downloaded.
class YouTubeVideo {
  final int id;
  final String youtubeVideoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final int durationSeconds;
  final String description;
  final DateTime dateAdded;

  const YouTubeVideo({
    this.id = 0,
    required this.youtubeVideoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.durationSeconds = 0,
    this.description = '',
    required this.dateAdded,
  });

  // ── Derived helpers ──────────────────────────────────────────────────────

  Duration get duration => Duration(seconds: durationSeconds);

  String get watchUrl =>
      'https://www.youtube.com/watch?v=$youtubeVideoId';

  String get thumbnailHd =>
      'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'youtubeVideoId': youtubeVideoId,
        'title': title,
        'channelName': channelName,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'description': description,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
      };

  factory YouTubeVideo.fromMap(Map<String, dynamic> map) => YouTubeVideo(
        id: map['id'] as int? ?? 0,
        youtubeVideoId: map['youtubeVideoId'] as String? ?? '',
        title: map['title'] as String? ?? 'Unknown Title',
        channelName: map['channelName'] as String? ?? 'Unknown Channel',
        thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
        durationSeconds: map['durationSeconds'] as int? ?? 0,
        description: map['description'] as String? ?? '',
        dateAdded: map['dateAdded'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int)
            : DateTime.now(),
      );

  /// Build from a YouTube Data API v3 video resource JSON object.
  factory YouTubeVideo.fromApiJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? {};
    final contentDetails =
        json['contentDetails'] as Map<String, dynamic>? ?? {};
    final id = (json['id'] is Map)
        ? (json['id'] as Map)['videoId'] as String? ?? ''
        : json['id'] as String? ?? '';

    return YouTubeVideo(
      youtubeVideoId: id,
      title: snippet['title'] as String? ?? 'Unknown Title',
      channelName: snippet['channelTitle'] as String? ?? 'Unknown Channel',
      thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
      durationSeconds: _parseDuration(
          contentDetails['duration'] as String?),
      description: snippet['description'] as String? ?? '',
      dateAdded: DateTime.now(),
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────

  static String _bestThumbnail(dynamic thumbnails) {
    if (thumbnails == null) return '';
    final t = thumbnails as Map<String, dynamic>;
    for (final key in ['high', 'medium', 'default']) {
      final entry = t[key];
      if (entry != null) {
        return entry['url'] as String? ?? '';
      }
    }
    return '';
  }

  /// Parses ISO 8601 duration (PT4M13S) to seconds.
  static int _parseDuration(String? iso) {
    if (iso == null || iso.isEmpty) return 0;
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final s = int.tryParse(m.group(3) ?? '0') ?? 0;
    return h * 3600 + min * 60 + s;
  }

  YouTubeVideo copyWith({
    int? id,
    String? youtubeVideoId,
    String? title,
    String? channelName,
    String? thumbnailUrl,
    int? durationSeconds,
    String? description,
    DateTime? dateAdded,
  }) =>
      YouTubeVideo(
        id: id ?? this.id,
        youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
        title: title ?? this.title,
        channelName: channelName ?? this.channelName,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        description: description ?? this.description,
        dateAdded: dateAdded ?? this.dateAdded,
      );

  @override
  String toString() =>
      'YouTubeVideo($youtubeVideoId, "$title", channel: $channelName)';
}
