import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../models/youtube_video.dart';
import '../providers/youtube_provider.dart';
import '../utils/duration_formatter.dart';

class YouTubeVideoTile extends ConsumerWidget {
  final YouTubeVideo video;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const YouTubeVideoTile({
    super.key,
    required this.video,
    this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(youtubeFavoriteNotifierProvider)
        .contains(video.youtubeVideoId);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _Thumbnail(video: video),
      title: Text(
        video.title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.channelName,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.play_circle_outline,
                  size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 3),
              Text(
                video.durationSeconds > 0
                    ? formatDuration(video.duration)
                    : '–:––',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              // YouTube badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'YouTube',
                  style: TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => ref
                .read(youtubeFavoriteNotifierProvider.notifier)
                .toggle(video.youtubeVideoId),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppTheme.accentHeart : AppTheme.iconInactive,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onMoreTap,
            child: const Icon(
              Icons.more_vert,
              color: AppTheme.iconInactive,
              size: 20,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ─── Thumbnail ────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final YouTubeVideo video;
  const _Thumbnail({required this.video});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.bgCard,
                      child: const Icon(Icons.play_circle_outline,
                          color: AppTheme.textMuted, size: 24),
                    ),
                    errorWidget: (_, __, ___) => _FallbackThumb(),
                  )
                : _FallbackThumb(),
            // YouTube play icon overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgCard,
      child: const Icon(Icons.smart_display_rounded,
          color: Color(0xFFFF4444), size: 28),
    );
  }
}
