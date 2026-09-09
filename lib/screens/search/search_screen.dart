import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/youtube_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/youtube_video_tile.dart';
import '../youtube/youtube_details_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      final mode =
          _tabController.index == 0 ? SearchMode.library : SearchMode.youtube;
      ref.read(searchModeProvider.notifier).state = mode;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(searchModeProvider);
    final localQuery = ref.watch(searchQueryProvider);
    final ytQuery = ref.watch(youtubeSearchQueryProvider);
    final activeQuery = mode == SearchMode.library ? localQuery : ytQuery;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Search',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SearchBarWidget(
                hint: mode == SearchMode.library
                    ? 'Songs, artists, albums…'
                    : 'Search YouTube…',
                onChanged: (v) {
                  if (mode == SearchMode.library) {
                    ref.read(searchQueryProvider.notifier).state = v;
                  } else {
                    ref.read(youtubeSearchQueryProvider.notifier).state = v;
                  }
                },
                onClear: () {
                  ref.read(searchQueryProvider.notifier).state = '';
                  ref.read(youtubeSearchQueryProvider.notifier).state = '';
                },
              ),
            ),

            // ── Tab bar: My Library / YouTube ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryVariant],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'My Library'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_display, size: 14),
                          SizedBox(width: 4),
                          Text('YouTube'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Results ────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Local Library Tab ──────────────────────────────────
                  _LocalSearchResults(query: localQuery),

                  // ── YouTube Tab ────────────────────────────────────────
                  _YouTubeSearchResults(query: ytQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Local library results ────────────────────────────────────────────────────

class _LocalSearchResults extends ConsumerWidget {
  final String query;
  const _LocalSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final currentSong = ref.watch(playerProvider).currentSong;

    if (query.isEmpty) return const _SearchEmptyHint(isYouTube: false);

    return resultsAsync.when(
      data: (songs) {
        if (songs.isEmpty) return _NoResults(query: query, isYouTube: false);
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
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── YouTube results ──────────────────────────────────────────────────────────

class _YouTubeSearchResults extends ConsumerWidget {
  final String query;
  const _YouTubeSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(youtubeSearchProvider);
    final errorMsg = ref.watch(youtubeSearchErrorProvider);

    if (query.isEmpty) return const _SearchEmptyHint(isYouTube: true);

    return resultsAsync.when(
      data: (videos) {
        if (videos.isEmpty && !resultsAsync.isLoading) {
          return _NoResults(query: query, isYouTube: true);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120, top: 8),
          itemCount: videos.length,
          itemBuilder: (_, i) {
            final video = videos[i];
            return YouTubeVideoTile(
              video: video,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => YouTubeDetailsScreen(video: video),
                ),
              ),
              onMoreTap: () => _showOptions(context, ref, video),
            );
          },
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Searching YouTube…',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      ),
      error: (_, __) => _YouTubeError(message: errorMsg),
    );
  }

  void _showOptions(
      BuildContext context, WidgetRef ref, dynamic video) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined,
                  color: AppTheme.primary),
              title: const Text('Save to Library',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(databaseServiceProvider)
                    .saveYouTubeVideo(video);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Saved to library'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline,
                  color: AppTheme.textSecondary),
              title: const Text('View details',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => YouTubeDetailsScreen(video: video),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Error widget ─────────────────────────────────────────────────────────────

class _YouTubeError extends StatelessWidget {
  final String? message;
  const _YouTubeError({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              message ?? 'Unable to search YouTube right now.',
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

// ─── Empty search hint ────────────────────────────────────────────────────────

class _SearchEmptyHint extends StatelessWidget {
  final bool isYouTube;
  const _SearchEmptyHint({required this.isYouTube});

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgCard,
              ),
              child: Icon(
                isYouTube
                    ? Icons.smart_display_rounded
                    : Icons.search_rounded,
                size: 48,
                color: isYouTube
                    ? const Color(0xFFFF4444)
                    : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isYouTube ? 'Search YouTube' : 'Find your music',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isYouTube
                  ? 'Search for videos, music, artists on YouTube'
                  : 'Search by song name, artist or album',
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

// ─── No results ───────────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  final bool isYouTube;
  const _NoResults({required this.query, required this.isYouTube});

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
              '"$query" didn\'t match any ${isYouTube ? 'YouTube videos' : 'songs in your library'}.',
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
