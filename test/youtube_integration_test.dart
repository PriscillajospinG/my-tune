import 'package:flutter_test/flutter_test.dart';
import 'package:mytune/models/media_source_type.dart';
import 'package:mytune/models/youtube_video.dart';
import 'package:mytune/utils/duration_formatter.dart';

void main() {
  group('YouTubeVideo Model Unit Tests', () {
    test('YouTubeVideo toMap and fromMap serialization', () {
      final now = DateTime(2025, 6, 15, 12, 0);
      final video = YouTubeVideo(
        id: 10,
        youtubeVideoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        channelName: 'Rick Astley',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        durationSeconds: 213,
        description: 'Official music video for Never Gonna Give You Up',
        dateAdded: now,
      );

      final map = video.toMap();
      expect(map['youtubeVideoId'], 'dQw4w9WgXcQ');
      expect(map['title'], 'Never Gonna Give You Up');
      expect(map['channelName'], 'Rick Astley');
      expect(map['thumbnailUrl'],
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
      expect(map['durationSeconds'], 213);
      expect(map['description'],
          'Official music video for Never Gonna Give You Up');
      expect(map['dateAdded'], now.millisecondsSinceEpoch);

      final deserialized = YouTubeVideo.fromMap({
        ...map,
        'id': 10,
      });
      expect(deserialized.id, 10);
      expect(deserialized.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(deserialized.title, 'Never Gonna Give You Up');
      expect(deserialized.channelName, 'Rick Astley');
      expect(deserialized.thumbnailUrl,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
      expect(deserialized.durationSeconds, 213);
      expect(deserialized.description,
          'Official music video for Never Gonna Give You Up');
      expect(deserialized.dateAdded.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    });

    test('YouTubeVideo helper properties', () {
      final video = YouTubeVideo(
        youtubeVideoId: 'dQw4w9WgXcQ',
        title: 'Title',
        channelName: 'Channel',
        thumbnailUrl: 'http://example.com/thumb.jpg',
        durationSeconds: 125,
        dateAdded: DateTime.now(),
      );

      expect(video.watchUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(video.thumbnailHd,
          'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
      expect(video.duration.inSeconds, 125);
      expect(formatDuration(video.duration), '02:05');
    });

    test('YouTubeVideo fromApiJson parses snippet and contentDetails', () {
      final json = {
        'id': 'video1234567',
        'snippet': {
          'title': 'API Video Title',
          'channelTitle': 'API Channel',
          'thumbnails': {
            'high': {'url': 'https://example.com/high.jpg'},
          },
          'description': 'Description from API',
        },
        'contentDetails': {
          'duration': 'PT3M45S',
        },
      };

      final video = YouTubeVideo.fromApiJson(json);
      expect(video.youtubeVideoId, 'video1234567');
      expect(video.title, 'API Video Title');
      expect(video.channelName, 'API Channel');
      expect(video.thumbnailUrl, 'https://example.com/high.jpg');
      expect(video.durationSeconds, 225); // 3 * 60 + 45
      expect(video.description, 'Description from API');
    });

    test('YouTubeVideo copyWith produces correct mutated copy', () {
      final original = YouTubeVideo(
        id: 1,
        youtubeVideoId: 'abc12345678',
        title: 'Original Title',
        channelName: 'Channel A',
        thumbnailUrl: 'thumb.jpg',
        durationSeconds: 60,
        dateAdded: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        durationSeconds: 120,
      );

      expect(updated.id, original.id);
      expect(updated.youtubeVideoId, original.youtubeVideoId);
      expect(updated.title, 'Updated Title');
      expect(updated.channelName, original.channelName);
      expect(updated.durationSeconds, 120);
    });
  });

  group('MediaSourceType Enum Tests', () {
    test('MediaSourceType values match expectations', () {
      expect(MediaSourceType.local.value, 'local');
      expect(MediaSourceType.youtube.value, 'youtube');
    });

    test('MediaSourceType fromValue parses correctly', () {
      expect(MediaSourceType.fromValue('local'), MediaSourceType.local);
      expect(MediaSourceType.fromValue('youtube'), MediaSourceType.youtube);
      expect(MediaSourceType.fromValue('unknown'), MediaSourceType.local);
      expect(MediaSourceType.fromValue(null), MediaSourceType.local);
    });
  });
}
