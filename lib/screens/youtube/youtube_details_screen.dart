import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../models/youtube_video.dart';
import '../../providers/youtube_provider.dart';
import '../../services/database_service.dart';
import '../../utils/duration_formatter.dart';

class YouTubeDetailsScreen extends ConsumerStatefulWidget {
  final YouTubeVideo video;

  const YouTubeDetailsScreen({super.key, required this.video});

  @override
  ConsumerState<YouTubeDetailsScreen> createState() =>
      _YouTubeDetailsScreenState();
}

class _YouTubeDetailsScreenState
    extends ConsumerState<YouTubeDetailsScreen> {
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final db = ref.read(databaseServiceProvider);
    final s = await db.isYouTubeVideoSaved(widget.video.youtubeVideoId);
    if (mounted) setState(() => _saved = s);
  }

  Future<void> _toggleSave() async {
    setState(() => _saving = true);
    final db = ref.read(databaseServiceProvider);
    try {
      if (_saved) {
        await db.deleteYouTubeVideo(widget.video.youtubeVideoId);
        if (mounted) setState(() => _saved = false);
      } else {
        await db.saveYouTubeVideo(widget.video);
        if (mounted) setState(() => _saved = true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openInYouTube() async {
    final videoId = widget.video.youtubeVideoId;
    final appUri = Uri.parse('youtube://watch?v=$videoId');
    final webUri = Uri.parse(widget.video.watchUrl);

    bool launched = false;
    try {
      if (await canLaunchUrl(appUri)) {
        launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      }
      if (!launched && await canLaunchUrl(webUri)) {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      launched = false;
    }

    if (launched) {
      // Record the play in recently played
      await ref
          .read(databaseServiceProvider)
          .recordYouTubePlay(widget.video.youtubeVideoId);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open YouTube link.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _addToPlaylist() async {
    final playlists = await ref
        .read(databaseServiceProvider)
        .getAllPlaylists();

    if (!mounted) return;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No playlists yet. Create one first.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _PlaylistPicker(
        playlists: playlists,
        onSelect: (playlistId) async {
          await ref
              .read(databaseServiceProvider)
              .addYouTubeVideoToPlaylist(
                  playlistId, widget.video.youtubeVideoId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Added to playlist'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final isFav = ref.watch(youtubeFavoriteNotifierProvider)
        .contains(video.youtubeVideoId);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: CustomScrollView(
        slivers: [
          // ── App bar with thumbnail ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.bgDeep,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  video.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppTheme.bgCard),
                          errorWidget: (context, url, error) =>
                              Container(color: AppTheme.bgCard),
                        )
                      : Container(color: AppTheme.bgCard),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                      ),
                    ),
                  ),
                  // YouTube badge
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_display,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'YouTube',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Channel + duration
                  Row(
                    children: [
                      const Icon(Icons.account_circle_rounded,
                          size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          video.channelName,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (video.durationSeconds > 0)
                        Text(
                          formatDuration(video.duration),
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Action buttons ────────────────────────────────────────
                  // Primary: Open in YouTube
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInYouTube,
                      icon: const Icon(Icons.smart_display_rounded,
                          color: Colors.white),
                      label: const Text('Open in YouTube',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary row: Save, Favorite, Add to Playlist
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: _saving
                              ? null
                              : (_saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border),
                          label: _saved ? 'Saved' : 'Save',
                          active: _saved,
                          isLoading: _saving,
                          onTap: _toggleSave,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          icon: isFav
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: isFav ? 'Favorited' : 'Favorite',
                          active: isFav,
                          color: AppTheme.accentHeart,
                          onTap: () => ref
                              .read(youtubeFavoriteNotifierProvider.notifier)
                              .toggle(video.youtubeVideoId),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.playlist_add,
                          label: 'Playlist',
                          onTap: _addToPlaylist,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Playback notice ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.divider, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.textMuted, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'YouTube content plays in the YouTube app or browser. '
                            'In-app background audio is not supported for YouTube per its Terms of Service.',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Description ───────────────────────────────────────────
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'About',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ExpandableDescription(text: video.description),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isLoading;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? AppTheme.primary : AppTheme.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? c.withValues(alpha: 0.4) : AppTheme.divider),
        ),
        child: Column(
          children: [
            isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: c, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Expandable description ───────────────────────────────────────────────────

class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState
    extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow:
                _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? 'Show less' : 'Show more',
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─── Playlist picker bottom sheet ─────────────────────────────────────────────

class _PlaylistPicker extends StatelessWidget {
  final List<dynamic> playlists;
  final Future<void> Function(int playlistId) onSelect;

  const _PlaylistPicker({required this.playlists, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              const Text('Add to Playlist',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          ...playlists.map((p) {
            final id = (p as dynamic).id as int;
            final name = p.name as String;
            return ListTile(
              leading: const Icon(Icons.queue_music, color: AppTheme.primary),
              title: Text(name,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                await onSelect(id);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
