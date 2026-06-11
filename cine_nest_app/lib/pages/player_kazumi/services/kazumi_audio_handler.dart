import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controller/player_controller.dart';

/// 后台播放 + 锁屏控件的 audio_service handler。
///
/// 用法：
/// ```dart
/// final handler = await ensureKazumiAudioHandler();
/// handler.attach(playerController);   // 绑定到某次播放
/// handler.setMediaInfo(title: ..., album: ...);
/// // 播放完毕后：
/// await handler.detach();
/// ```
///
/// 注：[AudioService.init] 全应用只能调用一次。这里用静态门保证幂等。
/// 失败时会被 catch 并打日志（Android 需要在 manifest 注册 Foreground Service）。
class KazumiAudioHandler extends BaseAudioHandler with SeekHandler {
  KazumiPlayerController? _ctrl;
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;

  void attach(KazumiPlayerController c) {
    detach();
    _ctrl = c;
    _playingSub = c.player.stream.playing.listen(_syncPlayingState);
    _positionSub = c.player.stream.position
        .listen((p) => _patch(updatePosition: p));
    _durationSub = c.player.stream.duration
        .listen((d) => mediaItem.add((mediaItem.value ?? _empty).copyWith(duration: d)));
    _bufferingSub = c.player.stream.buffering.listen((b) {
      _patch(
        processingState:
            b ? AudioProcessingState.buffering : AudioProcessingState.ready,
      );
    });
    _completedSub = c.player.stream.completed.listen((done) {
      if (done) _patch(processingState: AudioProcessingState.completed);
    });
    _syncPlayingState(c.player.state.playing);
  }

  Future<void> detach() async {
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferingSub?.cancel();
    await _completedSub?.cancel();
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _bufferingSub = null;
    _completedSub = null;
    _ctrl = null;
    onSkipToNext = null;
    onSkipToPrevious = null;
  }

  void setMediaInfo({required String title, String? artist, String? album, Uri? artUri}) {
    final base = mediaItem.value ?? _empty;
    mediaItem.add(base.copyWith(
      title: title,
      artist: artist ?? base.artist,
      album: album ?? base.album,
      artUri: artUri ?? base.artUri,
    ));
  }

  void _syncPlayingState(bool playing) {
    _patch(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      playing: playing,
    );
  }

  void _patch({
    List<MediaControl>? controls,
    Set<MediaAction>? systemActions,
    bool? playing,
    AudioProcessingState? processingState,
    Duration? updatePosition,
  }) {
    final s = playbackState.value;
    playbackState.add(s.copyWith(
      controls: controls ?? s.controls,
      systemActions: systemActions ?? s.systemActions,
      playing: playing ?? s.playing,
      processingState: processingState ?? s.processingState,
      updatePosition: updatePosition ?? s.updatePosition,
    ));
  }

  @override
  Future<void> play() async => _ctrl?.play();
  @override
  Future<void> pause() async => _ctrl?.pause();
  @override
  Future<void> seek(Duration position) async => _ctrl?.seekTo(position);
  @override
  Future<void> skipToNext() async => onSkipToNext?.call();
  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();
  @override
  Future<void> stop() async {
    await _ctrl?.pause();
    await super.stop();
  }

  static final MediaItem _empty = const MediaItem(id: 'kazumi.player', title: 'CineNest');
}

KazumiAudioHandler? _instance;
bool _initStarted = false;

/// 幂等初始化 audio_service。失败时返回 null（不阻塞主流程）。
Future<KazumiAudioHandler?> ensureKazumiAudioHandler() async {
  if (_instance != null) return _instance;
  if (_initStarted) return null;
  _initStarted = true;
  try {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    _instance = await AudioService.init<KazumiAudioHandler>(
      builder: KazumiAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'cine_nest.player',
        androidNotificationChannelName: 'CineNest 播放器',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    return _instance;
  } catch (_) {
    return null;
  }
}
