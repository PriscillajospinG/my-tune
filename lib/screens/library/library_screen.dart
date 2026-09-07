import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/album_card.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/song_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _songFilter = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bgDeep,
            title: const Text('Library',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    fontFamily: 'Outfit')),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
                onPressed: () async {
                  final notifier = ref.read(libraryProvider.notifier);
                  final imported = await notifier.importSongs();
                  if (imported.isNotEmpty && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Imported ${imported.length} song(s)'),
                      backgroundColor: AppTheme.bgCard,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
                Tab(text: 'Playlists'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SongsTab(filter: _songFilter, onFilterChanged: (v) {
              setState(() => _songFilter = v);
            }),
            const _AlbumsTab(),
            const _ArtistsTab(),
            const _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Songs Tab ────────────────────────────────────────────────────────────

class _SongsTab extends ConsumerWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _SongsTab({required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsStreamProvider);
    final currentSong = ref.watch(playerProvider).currentSong;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBarWidget(
            hint: 'Filter songs…',
            onChanged: onFilterChanged,
            onClear: () => onFilterChanged(''),
          ),
        ),
        Expanded(
          child: songsAsync.when(
            data: (songs) {
              final filtered = filter.isEmpty
                  ? songs
                  : songs
                      .where((s) =>
                          s.title.toLowerCase().contains(filter.toLowerCase()) ||
                          s.artist.toLowerCase().contains(filter.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return _emptyState(
                  icon: Icons.music_off_rounded,
                  title: filter.isEmpty ? 'No songs yet' : 'No results',
                  sub: filter.isEmpty
                      ? 'Import music from the + button'
                      : 'Try a different search term',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final song = filtered[i];
                  return SongTile(
                    song: song,
                    isPlaying: currentSong?.id == song.id,
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: filtered);
                      context.pushNamed('now-playing');
                    },
                    onMoreTap: () =>
                        _showSongOptions(context, ref, song),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref, song) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SongOptionsSheet(song: song),
    );
  }

  Widget _emptyState(
      {required IconData icon, required String title, required String sub}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(sub,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Albums Tab ───────────────────────────────────────────────────────────

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsStreamProvider);
    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Center(
            child: Text('No albums yet',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.75,
          ),
          itemCount: albums.length,
          itemBuilder: (_, i) => AlbumCard(album: albums[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── Artists Tab ──────────────────────────────────────────────────────────

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsStreamProvider);
    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(
            child: Text('No artists yet',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.8,
          ),
          itemCount: artists.length,
          itemBuilder: (_, i) => ArtistCard(artist: artists[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── Playlists Tab ────────────────────────────────────────────────────────

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final db = ref.watch(databaseServiceProvider);

    return playlistsAsync.when(
      data: (playlists) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: playlists.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showCreatePlaylistDialog(context, ref),
                  icon: const Icon(Icons.add, color: AppTheme.primary),
                  label: const Text('New Playlist',
                      style: TextStyle(color: AppTheme.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            }
            final playlist = playlists[i - 1];
            return FutureBuilder(
              future: db.getSongsInPlaylist(playlist.id),
              builder: (_, snap) {
                final count = snap.data?.length ?? 0;
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.6),
                          AppTheme.accent.withValues(alpha: 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.queue_music,
                        color: Colors.white, size: 24),
                  ),
                  title: Text(playlist.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('$count songs',
                      style: const TextStyle(
                          color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted),
                  onTap: () => context.pushNamed('playlists'),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
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

// ─── Song options bottom sheet ────────────────────────────────────────────

class _SongOptionsSheet extends ConsumerWidget {
  final dynamic song;
  const _SongOptionsSheet({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteNotifierProvider).contains(song.id);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Text(song.title,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          Text(song.artist,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.divider),
          ListTile(
            leading: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppTheme.accentWarm : AppTheme.textSecondary,
            ),
            title: Text(
              isFav ? 'Remove from Favorites' : 'Add to Favorites',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            onTap: () {
              ref.read(favoriteNotifierProvider.notifier).toggle(song.id);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline,
                color: AppTheme.accentWarm),
            title: const Text('Remove from Library',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              ref.read(libraryProvider.notifier).deleteSong(song.id);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
