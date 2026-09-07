import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/playback_controls.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;
    final isFav = song != null
        ? ref.watch(favoriteNotifierProvider).contains(song.id)
        : false;

    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final gradients = AppConstants.gradientForId(song.id);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // ── Ambient gradient background ────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradients[0].withValues(alpha: 0.4),
                    AppTheme.bgDeep,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: AppTheme.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            children: [
                              const Text(
                                'Now Playing',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Favorite button
                      IconButton(
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav
                              ? AppTheme.accentWarm
                              : AppTheme.textSecondary,
                          size: 26,
                        ),
                        onPressed: () => ref
                            .read(favoriteNotifierProvider.notifier)
                            .toggle(song.id),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Album Art ────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _AlbumArtWidget(song: song),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Song Info ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${song.artist} • ${song.album}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Progress Bar ─────────────────────────────────
                const ProgressBarWidget(),

                const SizedBox(height: 16),

                // ── Playback Controls ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const PlaybackControls(large: true),
                ),

                const SizedBox(height: 16),

                // ── Queue mini view ──────────────────────────────
                if (player.queue.length > 1)
                  _QueuePreview(
                    queue: player.queue,
                    currentIndex: player.queue
                        .indexWhere((s) => s.id == song.id),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Album Art ────────────────────────────────────────────────────────────

class _AlbumArtWidget extends StatefulWidget {
  final dynamic song;
  const _AlbumArtWidget({required this.song});

  @override
  State<_AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends State<_AlbumArtWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradients = AppConstants.gradientForId(widget.song.id);
    return ScaleTransition(
      scale: _scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: widget.song.hasArt
            ? Image.memory(
                Uint8List.fromList(widget.song.albumArtBytes!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(gradients),
              )
            : _placeholder(gradients),
      ),
    );
  }

  Widget _placeholder(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white24,
        size: 96,
      ),
    );
  }
}

// ─── Queue Preview ────────────────────────────────────────────────────────

class _QueuePreview extends ConsumerWidget {
  final List queue;
  final int currentIndex;

  const _QueuePreview({required this.queue, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show up to 3 upcoming songs
    final upNext = queue
        .skip(currentIndex + 1)
        .take(3)
        .toList();

    if (upNext.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Up Next',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...upNext.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.music_note,
                        size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.title} — ${s.artist}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
