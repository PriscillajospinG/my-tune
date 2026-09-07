import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/song_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final currentSong = ref.watch(playerProvider).currentSong;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: const Text(
                'Search',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SearchBarWidget(
                hint: 'Songs, artists, albums…',
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                onClear: () =>
                    ref.read(searchQueryProvider.notifier).state = '',
              ),
            ),

            // ── Results ───────────────────────────────────────────
            Expanded(
              child: query.isEmpty
                  ? _SearchEmptyHint()
                  : resultsAsync.when(
                      data: (songs) {
                        if (songs.isEmpty) {
                          return _NoResults(query: query);
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120, top: 8),
                          itemCount: songs.length,
                          itemBuilder: (_, i) {
                            final song = songs[i];
                            return SongTile(
                              song: song,
                              isPlaying: currentSong?.id == song.id,
                              onTap: () {
                                ref
                                    .read(playerProvider.notifier)
                                    .playSong(song, queue: songs);
                                context.pushNamed('now-playing');
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Error: $e')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty search hint ────────────────────────────────────────────────────

class _SearchEmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgCard,
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Find your music',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search by song name, artist or album',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No results ───────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 20),
            const Text(
              'Nothing found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$query" didn\'t match any songs in your library.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
