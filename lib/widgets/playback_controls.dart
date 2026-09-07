import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/player_provider.dart';
import '../utils/duration_formatter.dart';

/// Full playback controls: shuffle, previous, play/pause, next, repeat
class PlaybackControls extends ConsumerWidget {
  final bool large;
  const PlaybackControls({super.key, this.large = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    final iconSize = large ? 32.0 : 22.0;
    final playSize = large ? 64.0 : 44.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        _IconBtn(
          icon: Icons.shuffle_rounded,
          size: iconSize,
          color: player.isShuffle ? AppTheme.primary : AppTheme.iconInactive,
          onTap: notifier.toggleShuffle,
        ),
        // Previous
        _IconBtn(
          icon: Icons.skip_previous_rounded,
          size: iconSize + 8,
          color: AppTheme.textPrimary,
          onTap: notifier.skipToPrevious,
        ),
        // Play / Pause
        _PlayButton(
          isPlaying: player.isPlaying,
          size: playSize,
          onTap: notifier.togglePlayPause,
        ),
        // Next
        _IconBtn(
          icon: Icons.skip_next_rounded,
          size: iconSize + 8,
          color: AppTheme.textPrimary,
          onTap: notifier.skipToNext,
        ),
        // Repeat
        _RepeatButton(
          repeatMode: player.repeatMode,
          size: iconSize,
          onTap: notifier.cycleRepeat,
        ),
      ],
    );
  }
}

/// Seek bar with position and duration labels
class ProgressBarWidget extends ConsumerStatefulWidget {
  const ProgressBarWidget({super.key});

  @override
  ConsumerState<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends ConsumerState<ProgressBarWidget> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final totalMs = player.duration.inMilliseconds.toDouble();
    final posMs = player.position.inMilliseconds.toDouble();

    final sliderValue = totalMs > 0
        ? (_dragValue ?? posMs).clamp(0.0, totalMs)
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: totalMs > 0 ? sliderValue / totalMs : 0,
            onChangeStart: (v) {
              setState(() => _dragValue = v * totalMs);
            },
            onChanged: totalMs > 0
                ? (v) => setState(() => _dragValue = v * totalMs)
                : null,
            onChangeEnd: (v) {
              final seekMs = (v * totalMs).round();
              ref
                  .read(playerProvider.notifier)
                  .seekTo(Duration(milliseconds: seekMs));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: sliderValue.toInt())),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
              Text(
                formatDuration(player.duration),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Private sub-widgets ──────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final double size;
  final VoidCallback? onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final AudioServiceRepeatMode repeatMode;
  final double size;
  final VoidCallback? onTap;

  const _RepeatButton({
    required this.repeatMode,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = repeatMode != AudioServiceRepeatMode.none;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          repeatMode == AudioServiceRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          color: isActive ? AppTheme.primary : AppTheme.iconInactive,
          size: size,
        ),
      ),
    );
  }
}
