import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/logger.dart';
import '../controller/player_controller.dart';

/// 后台播放 + 锁屏控件 + 通知栏媒体控件的 audio_service handler。
class KazumiAudioHandler extends BaseAudioHandler with SeekHandler {
  KazumiPlayerController? _ctrl;
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _rateSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;

  void attach(KazumiPlayerController c) {
    detach();
    _ctrl = c;
    _playingSub = c.player.stream.playing.listen(_syncPlayingState);
    _positionSub = c.player.stream.position.listen(
      (p) => _patch(updatePosition: p),
    );
    _durationSub = c.player.stream.duration.listen(_syncDuration);
    _bufferSub = c.player.stream.buffer.listen(
      (b) => _patch(bufferedPosition: b),
    );
    _rateSub = c.player.stream.rate.listen((r) => _patch(speed: r));
    _bufferingSub = c.player.stream.buffering.listen((b) {
      _patch(
        processingState: b
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
      );
    });
    _completedSub = c.player.stream.completed.listen((done) {
      if (done) _patch(processingState: AudioProcessingState.completed);
    });
    _syncSnapshot();
    logger.i('[AudioHandler] attached');
  }

  Future<void> detach() async {
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferSub?.cancel();
    await _rateSub?.cancel();
    await _bufferingSub?.cancel();
    await _completedSub?.cancel();
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _bufferSub = null;
    _rateSub = null;
    _bufferingSub = null;
    _completedSub = null;
    _ctrl = null;
    onSkipToNext = null;
    onSkipToPrevious = null;
  }

  void setMediaInfo({
    required String title,
    String? artist,
    String? album,
    Uri? artUri,
  }) {
    final base = mediaItem.value ?? _empty;
    mediaItem.add(
      base.copyWith(
        title: title,
        artist: artist ?? base.artist,
        album: album ?? base.album,
        artUri: artUri ?? base.artUri,
      ),
    );
  }

  void _syncDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    mediaItem.add((mediaItem.value ?? _empty).copyWith(duration: duration));
  }

  void _syncSnapshot() {
    final state = _ctrl?.player.state;
    if (state == null) {
      _patch(processingState: AudioProcessingState.ready);
      return;
    }
    _syncDuration(state.duration);
    _patch(
      controls: _controlsFor(state.playing),
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      playing: state.playing,
      processingState: state.completed
          ? AudioProcessingState.completed
          : state.buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      updatePosition: state.position,
      bufferedPosition: state.buffer,
      speed: state.rate,
    );
  }

  void _syncPlayingState(bool playing) {
    _patch(
      controls: _controlsFor(playing),
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
      playing: playing,
    );
  }

  List<MediaControl> _controlsFor(bool playing) => [
    MediaControl.skipToPrevious,
    if (playing) MediaControl.pause else MediaControl.play,
    MediaControl.skipToNext,
  ];

  void _patch({
    List<MediaControl>? controls,
    Set<MediaAction>? systemActions,
    bool? playing,
    AudioProcessingState? processingState,
    Duration? updatePosition,
    Duration? bufferedPosition,
    double? speed,
    List<int>? androidCompactActionIndices,
  }) {
    final s = playbackState.value;
    playbackState.add(
      s.copyWith(
        controls: controls ?? s.controls,
        androidCompactActionIndices:
            androidCompactActionIndices ?? s.androidCompactActionIndices,
        systemActions: systemActions ?? s.systemActions,
        playing: playing ?? s.playing,
        processingState: processingState ?? s.processingState,
        updatePosition: updatePosition ?? s.updatePosition,
        bufferedPosition: bufferedPosition ?? s.bufferedPosition,
        speed: speed ?? s.speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    logger.i('[AudioHandler] play');
    await _ctrl?.play();
    _syncSnapshot();
  }

  @override
  Future<void> pause() async {
    logger.i('[AudioHandler] pause');
    await _ctrl?.pause();
    _syncSnapshot();
  }

  @override
  Future<void> seek(Duration position) async {
    logger.i('[AudioHandler] seek $position');
    await _ctrl?.seekTo(position);
    _syncSnapshot();
  }

  @override
  Future<void> skipToNext() async {
    logger.i('[AudioHandler] skipToNext');
    onSkipToNext?.call();
    _syncSnapshot();
  }

  @override
  Future<void> skipToPrevious() async {
    logger.i('[AudioHandler] skipToPrevious');
    onSkipToPrevious?.call();
    _syncSnapshot();
  }

  @override
  Future<void> stop() async {
    logger.i('[AudioHandler] stop');
    await _ctrl?.pause();
    await super.stop();
  }

  static const MediaItem _empty = MediaItem(
    id: 'kazumi.player',
    title: 'CineNest',
  );
}

KazumiAudioHandler? _instance;
Future<KazumiAudioHandler?>? _initFuture;

Future<KazumiAudioHandler?> ensureKazumiAudioHandler() async {
  if (_instance != null) return _instance;
  return _initFuture ??= _initAudioHandler();
}

Future<KazumiAudioHandler?> _initAudioHandler() async {
  try {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      logger.i('[AudioHandler] notification permission: $status');
    }
    _instance = await AudioService.init<KazumiAudioHandler>(
      builder: KazumiAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'cine_nest.player',
        androidNotificationChannelName: 'CineNest 播放器',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
    logger.i('[AudioHandler] init OK');
    return _instance;
  } catch (e, st) {
    logger.e('[AudioHandler] init FAILED: $e\n$st');
    return null;
  } finally {
    if (_instance == null) {
      _initFuture = null;
    }
  }
}
