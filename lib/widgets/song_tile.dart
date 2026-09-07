import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../models/song.dart';
import '../providers/playlist_provider.dart';
import '../utils/constants.dart';
import '../utils/duration_formatter.dart';

/// A single song list tile. Displays album art, title, artist, and duration.
class SongTile extends ConsumerWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final bool showArt;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    this.onTap,
    this.onMoreTap,
    this.showArt = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteNotifierProvider).contains(song.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: showArt ? _buildArt() : null,
      title: Text(
        song.title,
        style: TextStyle(
          color: isPlaying ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.artist} • ${song.album}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            const _PlayingIndicator()
          else
            Text(
              formatDuration(song.duration),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onMoreTap,
            child: Icon(
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

  Widget _buildArt() {
    final gradients = AppConstants.gradientForId(song.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: song.hasArt
            ? Image.memory(
                Uint8List.fromList(song.albumArtBytes!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradient(gradients),
              )
            : _gradient(gradients),
      ),
    );
  }

  Widget _gradient(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 22),
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final offset = i * 0.3;
              final h = 4 + 10 * (((_ctrl.value + offset) % 1.0));
              return Container(
                width: 3,
                height: h.clamp(4, 14),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
