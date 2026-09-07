import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/song_tile.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Playlists',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  // Create playlist button
                  GestureDetector(
                    onTap: () =>
                        _showCreateDialog(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add,
                          color: AppTheme.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ── List ──────────────────────────────────────────────
            Expanded(
              child: playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return _EmptyPlaylists(
                        onCreate: () => _showCreateDialog(context, ref));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 120),
                    itemCount: playlists.length,
                    itemBuilder: (_, i) =>
                        _PlaylistTile(playlist: playlists[i]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('New Playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .create(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─── Playlist Tile ────────────────────────────────────────────────────────

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);

    return FutureBuilder<List<Song>>(
      future: db.getSongsInPlaylist(playlist.id),
      builder: (_, snap) {
        final songs = snap.data ?? [];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showPlaylistDetail(context, ref, playlist, songs),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Gradient thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.7),
                          AppTheme.accent.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.queue_music,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${songs.length} songs',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Options
                  PopupMenuButton<String>(
                    color: AppTheme.bgModal,
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.textMuted),
                    onSelected: (val) =>
                        _onMenuSelected(context, ref, val),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename',
                            style:
                                TextStyle(color: AppTheme.textPrimary)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style:
                                TextStyle(color: AppTheme.accentWarm)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onMenuSelected(
      BuildContext context, WidgetRef ref, String value) {
    if (value == 'rename') {
      _showRenameDialog(context, ref);
    } else if (value == 'delete') {
      _showDeleteDialog(context, ref);
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Rename Playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .rename(playlist.id, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Delete Playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete "${playlist.name}"? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(playlistProvider.notifier)
                  .delete(playlist.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentWarm),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPlaylistDetail(BuildContext context, WidgetRef ref,
      Playlist playlist, List<Song> songs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlaylistDetailSheet(
          playlist: playlist, initialSongs: songs),
    );
  }
}

// ─── Playlist Detail Sheet ────────────────────────────────────────────────

class _PlaylistDetailSheet extends ConsumerStatefulWidget {
  final Playlist playlist;
  final List<Song> initialSongs;

  const _PlaylistDetailSheet(
      {required this.playlist, required this.initialSongs});

  @override
  ConsumerState<_PlaylistDetailSheet> createState() =>
      _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState
    extends ConsumerState<_PlaylistDetailSheet> {
  late List<Song> _songs;

  @override
  void initState() {
    super.initState();
    _songs = widget.initialSongs;
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(playerProvider).currentSong;
    final height = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.playlist.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_songs.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(_songs.first, queue: _songs);
                      Navigator.pop(context);
                      context.pushNamed('now-playing');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${_songs.length} songs',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const Divider(color: AppTheme.divider, height: 24),

          // Songs list
          Expanded(
            child: _songs.isEmpty
                ? _emptyPlaylist()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _songs.length,
                    itemBuilder: (_, i) {
                      final song = _songs[i];
                      return SongTile(
                        song: song,
                        isPlaying: currentSong?.id == song.id,
                        onTap: () {
                          ref
                              .read(playerProvider.notifier)
                              .playSong(song, queue: _songs);
                          Navigator.pop(context);
                          context.pushNamed('now-playing');
                        },
                        onMoreTap: () =>
                            _showRemoveDialog(context, ref, song),
                      );
                    },
                  ),
          ),

          // Add songs button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddSongsSheet(context, ref),
                icon: const Icon(Icons.add, color: AppTheme.primary),
                label: const Text('Add Songs',
                    style: TextStyle(color: AppTheme.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPlaylist() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 64, color: AppTheme.textMuted),
          SizedBox(height: 16),
          Text('No songs in this playlist',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  void _showRemoveDialog(
      BuildContext context, WidgetRef ref, Song song) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Remove Song',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove "${song.title}" from this playlist?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(playlistProvider.notifier)
                  .removeSong(widget.playlist.id, song.id);
              setState(() => _songs.removeWhere((s) => s.id == song.id));
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentWarm),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddSongsSheet(BuildContext context, WidgetRef ref) {
    final allSongsAsync = ref.read(songsStreamProvider);
    allSongsAsync.whenData((allSongs) {
      final notInPlaylist =
          allSongs.where((s) => !_songs.any((p) => p.id == s.id)).toList();
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.bgModal,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              const Text('Add Songs',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Divider(color: AppTheme.divider),
              Expanded(
                child: notInPlaylist.isEmpty
                    ? const Center(
                        child: Text('All songs are already added',
                            style: TextStyle(
                                color: AppTheme.textSecondary)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: notInPlaylist.length,
                        itemBuilder: (_, i) {
                          final song = notInPlaylist[i];
                          return ListTile(
                            leading: const Icon(Icons.music_note,
                                color: AppTheme.textMuted),
                            title: Text(song.title,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary)),
                            subtitle: Text(song.artist,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                            trailing: const Icon(Icons.add_circle,
                                color: AppTheme.primary),
                            onTap: () async {
                              await ref
                                  .read(playlistProvider.notifier)
                                  .addSong(widget.playlist.id, song.id);
                              setState(() => _songs.add(song));
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ─── Empty Playlists ──────────────────────────────────────────────────────

class _EmptyPlaylists extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlaylists({required this.onCreate});

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
              child: const Icon(Icons.queue_music_rounded,
                  size: 52, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const Text('No playlists yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Create a playlist to organise your music.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
