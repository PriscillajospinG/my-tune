import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/song_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final favsAsync = ref.watch(favoriteSongsProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            backgroundColor: AppTheme.bgDeep,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'What\'s playing today?',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Import FAB in header
                    _ImportButton(),
                  ],
                ),
              ),
            ),
          ),

          // ── Recently Played ──────────────────────────────────────
          recentAsync.when(
            data: (songs) => songs.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : _HorizontalSection(
                    title: 'Recently Played',
                    child: _RecentlyPlayedRow(songs: songs),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Favorites ────────────────────────────────────────────
          favsAsync.when(
            data: (songs) => songs.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : _HorizontalSection(
                    title: 'Favorites ♥',
                    child: _FavoritesRow(songs: songs),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Playlists ────────────────────────────────────────────
          playlistsAsync.when(
            data: (playlists) => playlists.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : _HorizontalSection(
                    title: 'Playlists',
                    child: _PlaylistsRow(playlists: playlists),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Empty state ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: recentAsync.when(
              data: (songs) => songs.isEmpty ? const _EmptyHome() : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Bottom spacing for mini player
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 🌅';
    if (h < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }
}

// ─── Import Button ────────────────────────────────────────────────────────

class _ImportButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(libraryProvider.notifier);
        final imported = await notifier.importSongs();
        if (imported.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported ${imported.length} song(s)'),
              backgroundColor: AppTheme.bgCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh home providers
          ref.invalidate(recentlyPlayedProvider);
          ref.invalidate(favoriteSongsProvider);
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryVariant],
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Section wrapper ──────────────────────────────────────────────────────

class _HorizontalSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _HorizontalSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── Recently Played Row ──────────────────────────────────────────────────

class _RecentlyPlayedRow extends ConsumerWidget {
  final List<Song> songs;
  const _RecentlyPlayedRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final song = songs[i];
          final gradients = AppConstants.gradientForId(song.id);
          return GestureDetector(
            onTap: () {
              ref.read(playerProvider.notifier).playSong(song, queue: songs);
              context.pushNamed('now-playing');
            },
            child: SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: song.hasArt
                          ? Image.memory(
                              Uint8List.fromList(song.albumArtBytes!),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradients,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white30, size: 48),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Favorites Row ────────────────────────────────────────────────────────

class _FavoritesRow extends ConsumerWidget {
  final List<Song> songs;
  const _FavoritesRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(playerProvider).currentSong;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: songs.take(5).length,
      itemBuilder: (_, i) {
        final song = songs[i];
        return SongTile(
          song: song,
          isPlaying: currentSong?.id == song.id,
          onTap: () {
            ref.read(playerProvider.notifier).playSong(song, queue: songs);
            context.pushNamed('now-playing');
          },
        );
      },
    );
  }
}

// ─── Playlists Row ────────────────────────────────────────────────────────

class _PlaylistsRow extends ConsumerWidget {
  final List playlists;
  const _PlaylistsRow({required this.playlists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final playlist = playlists[i];
          final gradients = AppConstants.gradientForId(playlist.id);
          return GestureDetector(
            onTap: () => context.goNamed('playlists'),
            child: SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradients,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.queue_music,
                            color: Colors.white24, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Empty Home ───────────────────────────────────────────────────────────

class _EmptyHome extends ConsumerWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  AppTheme.accent.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.music_off_rounded,
              size: 56,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No music yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to import songs from your device and start listening.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () async {
              final notifier = ref.read(libraryProvider.notifier);
              await notifier.importSongs();
              ref.invalidate(recentlyPlayedProvider);
              ref.invalidate(favoriteSongsProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Import Music'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
