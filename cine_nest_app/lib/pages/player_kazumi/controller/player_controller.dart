import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

import '../../../services/logger.dart';

/// 播放器核心控制器（GetX 包装 media_kit Player + VideoController）。
///
/// 交互目标（对齐 CodeReference/Kazumi 的体验）：
/// - 双击：桌面切全屏，移动端播/暂停
/// - 长按：临时 2x 倍速，松开恢复
/// - 横滑：seek 预览（指尖移动只更新预览位置，离手才真正 seek）
/// - 左侧竖滑：亮度
/// - 右侧竖滑：音量（80ms 节流同步系统音量）
/// - 鼠标滚轮：音量
/// - 4 秒无操作控件自动隐藏
class KazumiPlayerController extends GetxController {
  KazumiPlayerController({
    this.bufferSizeBytes = 32 * 1024 * 1024,
    this.autoHideDelay = const Duration(seconds: 4),
    this.hudHideDelay = const Duration(milliseconds: 700),
    this.volumeSyncThrottle = const Duration(milliseconds: 80),
    this.gestureSeekScaleMs = 180000,
  });

  // ─── 配置 ────────────────────────────────────────────
  final int bufferSizeBytes;
  final Duration autoHideDelay;
  final Duration hudHideDelay;
  final Duration volumeSyncThrottle;

  /// 全屏一屏横滑 ≈ 多少毫秒的进度（默认 3 分钟）
  final int gestureSeekScaleMs;

  // ─── 媒体核心 ─────────────────────────────────────────
  late final Player player;
  late final VideoController videoController;

  // ─── 播放状态 ─────────────────────────────────────────
  final loading = true.obs;
  final playing = false.obs;
  final buffering = true.obs;
  final completed = false.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final buffer = Duration.zero.obs;
  final speed = 1.0.obs;

  /// 0..100
  final volume = 100.0.obs;

  /// 0..1
  final brightness = 0.5.obs;

  /// 1=auto, 2=cover (BoxFit.cover), 3=fill (BoxFit.fill)
  final aspectRatioType = 1.obs;

  // ─── UI 状态 ──────────────────────────────────────────
  final showControls = true.obs;
  final lockPanel = false.obs;
  final isFullscreen = false.obs;
  final showVolumeHud = false.obs;
  final showBrightnessHud = false.obs;
  final showSpeedHud = false.obs;
  final showSeekHud = false.obs;
  final seekTargetMs = 0.obs;

  /// -1=向左，0=无，1=向右
  final seekDirection = 0.obs;

  final lastError = ''.obs;

  // ─── 内部 ─────────────────────────────────────────────
  final List<StreamSubscription> _subs = [];
  Timer? _hideTimer;
  Timer? _hudHideTimer;
  Timer? _volumeGestureSyncTimer;
  double? _pendingGestureVolume;
  double _savedSpeedBeforeLongPress = 1.0;
  bool _initialized = false;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // ═══════════════════════════════════════════════════════
  //  生命周期
  // ═══════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    _ensureInitialized();
  }

  void _ensureInitialized() {
    if (_initialized) return;
    player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSizeBytes,
        osc: false,
      ),
    );
    videoController = VideoController(player);
    _wireStreams();
    _initialized = true;
  }

  void _wireStreams() {
    _subs.addAll([
      player.stream.playing.listen((v) => playing.value = v),
      player.stream.buffering.listen((v) => buffering.value = v),
      player.stream.completed.listen((v) => completed.value = v),
      player.stream.position.listen((v) => position.value = v),
      player.stream.duration.listen((v) => duration.value = v),
      player.stream.buffer.listen((v) => buffer.value = v),
      player.stream.rate.listen((v) => speed.value = v),
      player.stream.volume.listen((v) {
        // 桌面端音量直接来自 player；移动端音量走系统接口，不被 player.stream.volume 主导
        if (isDesktop) volume.value = v;
      }),
      player.stream.error.listen((e) {
        lastError.value = e.toString();
        logger.e('KazumiPlayer error: $e');
      }),
    ]);
  }

  @override
  Future<void> onClose() async {
    _cancelHideTimer();
    _cancelHudHideTimer();
    _volumeGestureSyncTimer?.cancel();
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    if (!isDesktop) {
      try {
        FlutterVolumeController.removeListener();
        await FlutterVolumeController.updateShowSystemUI(true);
      } catch (_) {}
    }
    try {
      await player.dispose();
    } catch (_) {}
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════
  //  打开媒体
  // ═══════════════════════════════════════════════════════

  Future<void> open({
    required String url,
    Map<String, String>? headers,
    Duration startAt = Duration.zero,
    bool autoPlay = true,
  }) async {
    _ensureInitialized();
    loading.value = true;
    lastError.value = '';
    try {
      await player.open(
        Media(url, start: startAt, httpHeaders: headers),
        play: autoPlay,
      );
      await _syncSystemVolumeInitial();
      await _syncSystemBrightnessInitial();
      showControlsTemporarily();
    } catch (e) {
      lastError.value = e.toString();
      logger.e('KazumiPlayer open failed: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> _syncSystemVolumeInitial() async {
    if (isDesktop) {
      try {
        await player.setVolume(volume.value);
      } catch (_) {}
      return;
    }
    try {
      final v = await FlutterVolumeController.getVolume();
      if (v != null) volume.value = (v * 100).clamp(0, 100);
      await FlutterVolumeController.updateShowSystemUI(false);
      FlutterVolumeController.addListener(
        (value) {
          // 手势进行中不被覆盖
          if (_pendingGestureVolume != null) return;
          volume.value = (value * 100).clamp(0, 100);
        },
        emitOnStart: false,
      );
    } catch (_) {}
  }

  Future<void> _syncSystemBrightnessInitial() async {
    if (isDesktop) return;
    try {
      final b = await ScreenBrightnessPlatform.instance.application;
      brightness.value = b.clamp(0.0, 1.0);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  基础控制
  // ═══════════════════════════════════════════════════════

  Future<void> playOrPause() async {
    try {
      if (player.state.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (_) {}
    showControlsTemporarily();
  }

  Future<void> play() async {
    try {
      await player.play();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await player.pause();
    } catch (_) {}
  }

  Future<void> seekTo(Duration to) async {
    final maxMs = duration.value.inMilliseconds;
    final clamped = Duration(
      milliseconds: to.inMilliseconds.clamp(0, maxMs <= 0 ? to.inMilliseconds : maxMs),
    );
    position.value = clamped;
    try {
      await player.seek(clamped);
    } catch (_) {}
  }

  Future<void> skipBy(Duration delta) async {
    await seekTo(position.value + delta);
  }

  Future<void> setSpeed(double s) async {
    speed.value = s;
    try {
      await player.setRate(s);
    } catch (_) {}
  }

  // ─── 长按倍速 ────────────────────────────────────────
  void beginLongPressSpeed({double target = 2.0}) {
    if (lockPanel.value) return;
    _savedSpeedBeforeLongPress = speed.value;
    showSpeedHud.value = true;
    setSpeed(target);
  }

  void endLongPressSpeed() {
    if (lockPanel.value) return;
    showSpeedHud.value = false;
    setSpeed(_savedSpeedBeforeLongPress);
  }

  // ═══════════════════════════════════════════════════════
  //  音量
  // ═══════════════════════════════════════════════════════

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 100.0);
    volume.value = clamped;
    await _syncSystemVolume(clamped);
  }

  void beginVolumeGesture() {
    _volumeGestureSyncTimer?.cancel();
    showBrightnessHud.value = false;
    showVolumeHud.value = true;
    _cancelHudHideTimer();
  }

  void updateVolumeGesture(double v) {
    final clamped = v.clamp(0.0, 100.0);
    _pendingGestureVolume = clamped;
    volume.value = clamped;
    _volumeGestureSyncTimer?.cancel();
    _volumeGestureSyncTimer = Timer(volumeSyncThrottle, () {
      final pending = _pendingGestureVolume;
      if (pending == null) return;
      _syncSystemVolume(pending);
    });
  }

  Future<void> finishVolumeGesture() async {
    _volumeGestureSyncTimer?.cancel();
    _volumeGestureSyncTimer = null;
    final pending = _pendingGestureVolume;
    _pendingGestureVolume = null;
    if (pending != null) {
      await _syncSystemVolume(pending);
    }
    _scheduleHudHide();
  }

  Future<void> _syncSystemVolume(double v) async {
    try {
      if (isDesktop) {
        await player.setVolume(v);
      } else {
        await FlutterVolumeController.setVolume(v / 100);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  亮度
  // ═══════════════════════════════════════════════════════

  Future<void> setBrightness(double b) async {
    final clamped = b.clamp(0.0, 1.0);
    brightness.value = clamped;
    if (isDesktop) return;
    try {
      await ScreenBrightnessPlatform.instance
          .setApplicationScreenBrightness(clamped);
    } catch (_) {}
  }

  void beginBrightnessGesture() {
    showVolumeHud.value = false;
    showBrightnessHud.value = true;
    _cancelHudHideTimer();
  }

  Future<void> updateBrightnessGesture(double b) => setBrightness(b);

  void finishBrightnessGesture() => _scheduleHudHide();

  // ═══════════════════════════════════════════════════════
  //  Seek 预览
  // ═══════════════════════════════════════════════════════

  void beginSeekPreview() {
    seekDirection.value = 0;
    seekTargetMs.value = position.value.inMilliseconds;
    showSeekHud.value = true;
    _cancelHideTimer();
  }

  /// [deltaMsScaled] 已经经过 gestureSeekScaleMs / screenWidth 缩放后的毫秒增量
  void updateSeekPreview({required int deltaMsScaled, required int directionSign}) {
    if (directionSign != 0) seekDirection.value = directionSign;
    final maxMs = duration.value.inMilliseconds;
    final target = (seekTargetMs.value + deltaMsScaled)
        .clamp(0, maxMs <= 0 ? seekTargetMs.value : maxMs);
    seekTargetMs.value = target;
  }

  Future<void> commitSeekPreview() async {
    final to = Duration(milliseconds: seekTargetMs.value);
    await seekTo(to);
    showSeekHud.value = false;
    seekDirection.value = 0;
    _startHideTimer();
  }

  void cancelSeekPreview() {
    showSeekHud.value = false;
    seekDirection.value = 0;
    _startHideTimer();
  }

  // ═══════════════════════════════════════════════════════
  //  控件可见性 / 锁 / 比例
  // ═══════════════════════════════════════════════════════

  void toggleControls() {
    if (showControls.value) {
      hideControls();
    } else {
      showControlsTemporarily();
    }
  }

  void showControlsTemporarily() {
    showControls.value = true;
    _startHideTimer();
  }

  void hideControls() {
    showControls.value = false;
    _cancelHideTimer();
  }

  void toggleLock() {
    lockPanel.value = !lockPanel.value;
    if (lockPanel.value) {
      _cancelHideTimer();
    } else {
      _startHideTimer();
    }
  }

  void cycleAspectRatio() {
    aspectRatioType.value = (aspectRatioType.value % 3) + 1;
    showControlsTemporarily();
  }

  void _startHideTimer() {
    _cancelHideTimer();
    _hideTimer = Timer(autoHideDelay, () {
      if (lockPanel.value) return;
      showControls.value = false;
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _scheduleHudHide() {
    _cancelHudHideTimer();
    _hudHideTimer = Timer(hudHideDelay, () {
      showVolumeHud.value = false;
      showBrightnessHud.value = false;
    });
  }

  void _cancelHudHideTimer() {
    _hudHideTimer?.cancel();
    _hudHideTimer = null;
  }

  // ═══════════════════════════════════════════════════════
  //  截图 / 全屏
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> screenshot() async {
    try {
      return await player.screenshot(format: 'image/png');
    } catch (e) {
      logger.w('screenshot failed: $e');
      return null;
    }
  }

  void setFullscreen(bool v) => isFullscreen.value = v;
  void toggleFullscreen() => isFullscreen.value = !isFullscreen.value;
}
