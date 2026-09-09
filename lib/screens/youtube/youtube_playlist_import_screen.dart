import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/youtube_video.dart';
import '../../repositories/youtube_repository.dart';
import '../../services/database_service.dart';
import '../../utils/youtube_url_parser.dart';
import '../../widgets/youtube_video_tile.dart';
import 'youtube_details_screen.dart';

class YouTubePlaylistImportScreen extends ConsumerStatefulWidget {
  const YouTubePlaylistImportScreen({super.key});

  @override
  ConsumerState<YouTubePlaylistImportScreen> createState() =>
      _YouTubePlaylistImportScreenState();
}

class _YouTubePlaylistImportScreenState
    extends ConsumerState<YouTubePlaylistImportScreen> {
  final _urlController = TextEditingController();
  bool _loading = false;
  bool _importing = false;
  String? _error;
  Map<String, dynamic>? _playlistMeta;
  List<YouTubeVideo>? _previewItems;
  Set<int> _selectedIndices = {};

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylist() async {
    final url = _urlController.text.trim();
    final playlistId = YouTubeUrlParser.extractPlaylistId(url);

    if (playlistId == null) {
      setState(() => _error = 'Please enter a valid YouTube playlist URL.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _playlistMeta = null;
      _previewItems = null;
      _selectedIndices = {};
    });

    final repo = ref.read(youTubeRepositoryProvider);

    final metaResult = await repo.getPlaylistDetails(playlistId);
    final itemsResult = await repo.getPlaylistItems(playlistId);

    if (!mounted) return;

    switch ((metaResult, itemsResult)) {
      case (
          YouTubeSuccess<Map<String, dynamic>?>(data: final meta),
          YouTubeSuccess<List<YouTubeVideo>>(data: final items)
        ):
        setState(() {
          _loading = false;
          _playlistMeta = meta;
          _previewItems = items;
          _selectedIndices = Set.from(
              Iterable.generate(items.length)); // all selected by default
        });
      case (YouTubeError<Map<String, dynamic>?>(:final message), _):
        setState(() {
          _loading = false;
          _error = message;
        });
      case (_, YouTubeError<List<YouTubeVideo>>(:final message)):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  Future<void> _importSelected() async {
    if (_previewItems == null || _selectedIndices.isEmpty) return;
    setState(() => _importing = true);

    final db = ref.read(databaseServiceProvider);
    int count = 0;

    for (final i in _selectedIndices) {
      final video = _previewItems![i];
      await db.saveYouTubeVideo(video);
      count++;
    }

    if (mounted) {
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count video${count == 1 ? '' : 's'} saved to library.'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        title: const Text('Import YouTube Playlist'),
        backgroundColor: AppTheme.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── URL input ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube playlist URL…',
                      hintStyle:
                          const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.link,
                          color: AppTheme.textMuted),
                      fillColor: AppTheme.bgCard,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                    onSubmitted: (_) => _fetchPlaylist(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _loading ? null : _fetchPlaylist,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),

          // ── Playlist meta header ──────────────────────────────────────────
          if (_playlistMeta != null)
            _PlaylistHeader(
              meta: _playlistMeta!,
              selectedCount: _selectedIndices.length,
              totalCount: _previewItems?.length ?? 0,
              onSelectAll: () => setState(() => _selectedIndices =
                  Set.from(Iterable.generate(_previewItems!.length))),
              onClearAll: () =>
                  setState(() => _selectedIndices = {}),
            ),

          // ── Video list ────────────────────────────────────────────────────
          Expanded(
            child: _previewItems == null
                ? _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _EmptyHint()
                : _previewItems!.isEmpty
                    ? const Center(
                        child: Text('No videos found in this playlist.',
                            style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _previewItems!.length,
                        itemBuilder: (_, i) {
                          final video = _previewItems![i];
                          final selected = _selectedIndices.contains(i);
                          return Stack(
                            children: [
                              YouTubeVideoTile(
                                video: video,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => YouTubeDetailsScreen(
                                        video: video),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Checkbox(
                                    value: selected,
                                    activeColor: AppTheme.primary,
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selectedIndices.add(i);
                                      } else {
                                        _selectedIndices.remove(i);
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),

      // ── Import FAB ────────────────────────────────────────────────────────
      floatingActionButton: (_previewItems != null &&
              _selectedIndices.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _importing ? null : _importSelected,
              backgroundColor: AppTheme.primary,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                _importing
                    ? 'Saving…'
                    : 'Save ${_selectedIndices.length} Video${_selectedIndices.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

// ─── Playlist meta header ──────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final Map<String, dynamic> meta;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _PlaylistHeader({
    required this.meta,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (meta['thumbnailUrl'] as String?)?.isNotEmpty == true
                ? Image.network(
                    meta['thumbnailUrl'] as String,
                    width: 56,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 40,
                      color: AppTheme.bgElevated,
                      child: const Icon(Icons.playlist_play,
                          color: AppTheme.textMuted),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 40,
                    color: AppTheme.bgElevated,
                    child: const Icon(Icons.playlist_play,
                        color: AppTheme.textMuted),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta['title'] as String? ?? 'Playlist',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$selectedCount / $totalCount selected',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: selectedCount == totalCount ? onClearAll : onSelectAll,
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.zero),
            child: Text(
              selectedCount == totalCount ? 'None' : 'All',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgCard,
              ),
              child: const Icon(Icons.playlist_play_rounded,
                  size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Paste a YouTube playlist URL above',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
