import 'package:flutter_test/flutter_test.dart';
import 'package:mytune/utils/youtube_url_parser.dart';

void main() {
  group('YouTubeUrlParser.extractVideoId', () {
    // ── Valid formats ────────────────────────────────────────────────────────

    test('parses youtube.com/watch?v=', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('parses youtube.com/watch?v= without www', () {
      const url = 'https://youtube.com/watch?v=dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('parses youtu.be shortlink', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('parses youtube.com/shorts/', () {
      const url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('parses youtube.com/embed/', () {
      const url = 'https://www.youtube.com/embed/dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('parses watch URL with extra query params', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxxx&index=3';
      expect(YouTubeUrlParser.extractVideoId(url), 'dQw4w9WgXcQ');
    });

    test('video ID with underscores and hyphens', () {
      // 11-char IDs with _ and - are valid
      const url = 'https://youtu.be/abc_-def123';
      expect(YouTubeUrlParser.extractVideoId(url), 'abc_-def123');
    });

    // ── Invalid / edge cases ─────────────────────────────────────────────────

    test('returns null for empty string', () {
      expect(YouTubeUrlParser.extractVideoId(''), isNull);
    });

    test('returns null for null', () {
      expect(YouTubeUrlParser.extractVideoId(null), isNull);
    });

    test('returns null for non-YouTube URL', () {
      expect(YouTubeUrlParser.extractVideoId('https://example.com/watch?v=abc'), isNull);
    });

    test('returns null for too-short video ID', () {
      // 10 chars = invalid
      expect(YouTubeUrlParser.extractVideoId('https://youtu.be/short1234'), isNull);
    });

    test('returns null for too-long video ID', () {
      // 12 chars = invalid
      expect(YouTubeUrlParser.extractVideoId('https://youtu.be/toolongidXXXX'), isNull);
    });

    test('returns null for invalid URL string', () {
      expect(YouTubeUrlParser.extractVideoId('not a url at all'), isNull);
    });

    test('returns null for playlist-only URL', () {
      const url = 'https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxx';
      expect(YouTubeUrlParser.extractVideoId(url), isNull);
    });
  });

  group('YouTubeUrlParser.extractPlaylistId', () {
    test('parses playlist?list=', () {
      const url = 'https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxx';
      expect(YouTubeUrlParser.extractPlaylistId(url), 'PLxxxxxxxxxxxxxxxxxxxx');
    });

    test('parses playlist from watch URL with list param', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxxxxxxxxxxxx123';
      expect(YouTubeUrlParser.extractPlaylistId(url), 'PLxxxxxxxxxxxx123');
    });

    test('returns null for empty string', () {
      expect(YouTubeUrlParser.extractPlaylistId(''), isNull);
    });

    test('returns null for null', () {
      expect(YouTubeUrlParser.extractPlaylistId(null), isNull);
    });

    test('returns null for non-YouTube URL', () {
      expect(YouTubeUrlParser.extractPlaylistId('https://example.com/list=PLabc'), isNull);
    });

    test('returns null for URL without list param', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractPlaylistId(url), isNull);
    });

    test('returns null for short playlist ID', () {
      // Less than 13 chars = invalid
      expect(YouTubeUrlParser.extractPlaylistId('https://www.youtube.com/playlist?list=PLabc'), isNull);
    });
  });

  group('YouTubeUrlParser helpers', () {
    test('isValidVideoId — valid', () {
      expect(YouTubeUrlParser.isValidVideoId('dQw4w9WgXcQ'), isTrue);
      expect(YouTubeUrlParser.isValidVideoId('abc_-def123'), isTrue);
    });

    test('isValidVideoId — invalid', () {
      expect(YouTubeUrlParser.isValidVideoId(null), isFalse);
      expect(YouTubeUrlParser.isValidVideoId('short'), isFalse);
      expect(YouTubeUrlParser.isValidVideoId('toolong123456'), isFalse);
      expect(YouTubeUrlParser.isValidVideoId('invalid!char1'), isFalse);
    });

    test('watchUrl builds correctly', () {
      expect(
        YouTubeUrlParser.watchUrl('dQw4w9WgXcQ'),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('playlistUrl builds correctly', () {
      expect(
        YouTubeUrlParser.playlistUrl('PLxxxxxxxxxxxxxxxxx'),
        'https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxx',
      );
    });
  });
}
