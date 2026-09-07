import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';

// ─── Player state model ────────────────────────────────────────────────────

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffle;
  final AudioServiceRepeatMode repeatMode;
  final List<Song> queue;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.queue = const [],
  });

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffle,
    AudioServiceRepeatMode? repeatMode,
    List<Song>? queue,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────

class PlayerNotifier extends Notifier<PlayerState> {
  late AudioPlayerService _service;

  @override
  PlayerState build() {
    _service = ref.watch(audioPlayerServiceProvider);

    // Listen to playback state changes
    _service.playbackState.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        position: ps.updatePosition,
        isShuffle: ps.shuffleMode == AudioServiceShuffleMode.all,
        repeatMode: ps.repeatMode,
      );
    });

    // Listen to position stream
    _service.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    // Listen to duration changes
    _service.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    // Listen to mediaItem changes (track changes)
    _service.mediaItem.listen((item) {
      if (item != null) {
        state = state.copyWith(
          currentSong: _service.currentSong,
          duration: item.duration ?? Duration.zero,
          queue: _service.currentQueue,
        );
      }
    });

    return const PlayerState();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    await _service.playSong(song, queue: queue);
    state = state.copyWith(
      currentSong: song,
      queue: queue ?? [song],
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> seekTo(Duration position) => _service.seek(position);

  Future<void> skipToNext() => _service.skipToNext();

  Future<void> skipToPrevious() => _service.skipToPrevious();

  Future<void> toggleShuffle() => _service.toggleShuffle();

  Future<void> cycleRepeat() => _service.cycleRepeatMode();

  Future<void> skipToIndex(int index) => _service.skipToQueueItem(index);
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
