import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'database_service.dart';

/// Riverpod provider — overridden in main.dart after AudioService.init()
final audioPlayerServiceProvider = Provider<AudioPlayerService>(
  (ref) => throw UnimplementedError('Override in ProviderScope'),
);

// ─────────────────────────────────────────────────────────────────────────────

class AudioPlayerService extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final DatabaseService _db;

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _shuffle = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  AudioPlayerService(this._db) {
    _init();
  }

  void _init() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      }
    });

    _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
        bufferedPosition: _player.bufferedPosition,
      ));
    });
  }

  // ── Public API ──────────────────────────────────────────────────────────

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = songs;
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);
    await _loadCurrent();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final songQueue = queue ?? [song];
    final idx = songQueue.indexWhere((s) => s.id == song.id);
    await loadQueue(songQueue, startIndex: idx < 0 ? 0 : idx);
    await play();
    await _db.recordPlay(song.id);
  }

  Song? get currentSong =>
      _queue.isEmpty ? null : _queue[_currentIndex];

  List<Song> get currentQueue => List.unmodifiable(_queue);

  bool get isShuffleOn => _shuffle;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  // ── BaseAudioHandler overrides ──────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _loadCurrent();
    await play();
    final song = currentSong;
    if (song != null) await _db.recordPlay(song.id);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _loadCurrent();
    await play();
    final song = currentSong;
    if (song != null) await _db.recordPlay(song.id);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _loadCurrent();
    await play();
    final song = currentSong;
    if (song != null) await _db.recordPlay(song.id);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => LoopMode.all,
      _ => LoopMode.off,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffle = shuffleMode == AudioServiceShuffleMode.all;
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  // ── Convenience toggles ─────────────────────────────────────────────────

  Future<void> toggleShuffle() async {
    await setShuffleMode(
      _shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
  }

  Future<void> cycleRepeatMode() async {
    await setRepeatMode(switch (_repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    });
  }

  // ── Streams ─────────────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _loadCurrent() async {
    if (_queue.isEmpty) return;
    final song = _queue[_currentIndex];
    mediaItem.add(_songToMediaItem(song));
    await _player.setFilePath(song.filePath);
  }

  void _onTrackComplete() {
    if (_repeatMode == AudioServiceRepeatMode.one) return;
    if (_currentIndex < _queue.length - 1) {
      skipToNext();
    } else if (_repeatMode == AudioServiceRepeatMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      _loadCurrent().then((_) => play());
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      shuffleMode: _shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: _repeatMode,
    ));
  }

  MediaItem _songToMediaItem(Song song) => MediaItem(
        id: song.filePath,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        extras: {'songId': song.id},
      );

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') await _player.dispose();
  }
}
