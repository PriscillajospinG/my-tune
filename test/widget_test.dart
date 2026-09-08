import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytune/app/theme.dart';
import 'package:mytune/models/song.dart';
import 'package:mytune/models/album.dart';
import 'package:mytune/models/artist.dart';
import 'package:mytune/models/playlist.dart';
import 'package:mytune/widgets/song_tile.dart';

void main() {
  group('Models Unit Tests', () {
    test('Song model serialization', () {
      final song = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        filePath: '/music/test.mp3',
        durationMs: 180000,
        dateAdded: DateTime(2025, 1, 1),
      );

      final map = song.toMap();
      expect(map['title'], 'Test Song');
      expect(map['artist'], 'Test Artist');
      expect(map['durationMs'], 180000);

      final fromMap = Song.fromMap(map);
      expect(fromMap.title, 'Test Song');
      expect(fromMap.duration.inMinutes, 3);
    });

    test('Album and Artist models', () {
      const album = Album(id: 1, name: 'Best Hits', artist: 'Pop Star');
      expect(album.name, 'Best Hits');
      expect(album.toMap()['name'], 'Best Hits');

      const artist = Artist(id: 1, name: 'Pop Star');
      expect(artist.name, 'Pop Star');
      expect(artist.toMap()['name'], 'Pop Star');
    });

    test('Playlist model', () {
      final playlist = Playlist(
        id: 1,
        name: 'My Favorites',
        createdAt: DateTime(2025, 1, 1),
      );
      expect(playlist.name, 'My Favorites');
      expect(playlist.toMap()['name'], 'My Favorites');
    });
  });

  group('Widget Tests', () {
    testWidgets('SongTile renders song information', (WidgetTester tester) async {
      final song = Song(
        id: 42,
        title: 'Midnight Echoes',
        artist: 'Luna Ray',
        album: 'Nightfall',
        filePath: '/path/song.mp3',
        durationMs: 215000,
        dateAdded: DateTime(2025, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SongTile(song: song),
            ),
          ),
        ),
      );

      expect(find.text('Midnight Echoes'), findsOneWidget);
      expect(find.text('Luna Ray • Nightfall'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
