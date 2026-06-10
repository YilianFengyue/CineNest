import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

import '../../../services/logger.dart';

/// 播放器核心控制器（GetX 包装 media_kit Player + VideoController）。
class KazumiPlayerController extends GetxController {
  KazumiPlayerController({
    this.bufferSizeBytes = 512 * 1024 * 1024,
    this.openTimeout = const Duration(seconds: 14),
    this.firstFrameTimeout = const Duration(seconds: 12),
    this.autoHideDelay = const Duration(seconds: 4),
    this.hudHideDelay = const Duration(milliseconds: 700),
    this.volumeSyncThrottle = const Duration(milliseconds: 80),
    this.gestureSeekScaleMs = 180000,
  }) {
    // 构造时立即建 Player + VideoController，避免 onInit 时机问题。
    player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSizeBytes,
        osc: false,
      ),
    );
    videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: Platform.isAndroid ? 'gpu' : null,
        enableHardwareAcceleration: true,
        hwdec: (Platform.isAndroid || Platform.isIOS) ? 'auto-safe' : null,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    _wireStreams();
    // 平台层调优放到下一帧，避免阻塞构造
    Future.microtask(_applyNativeTweaks);
  }

  // ─── 配置 ────────────────────────────────────────────
  final int bufferSizeBytes;
  final Duration openTimeout;
  final Duration firstFrameTimeout;
  final Duration autoHideDelay;
  final Duration hudHideDelay;
  final Duration volumeSyncThrottle;

  /// 全屏一屏横滑 ≈ 多少毫秒（默认 3 分钟）
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
  final volume = 100.0.obs;
  final brightness = 0.5.obs;
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
  final seekDirection = 0.obs;

  final lastError = ''.obs;

  // ─── 内部 ─────────────────────────────────────────────
  final List<StreamSubscription> _subs = [];
  Timer? _hideTimer;
  Timer? _hudHideTimer;
  Timer? _volumeGestureSyncTimer;
  double? _pendingGestureVolume;
  double _savedSpeedBeforeLongPress = 1.0;
  bool _opening = false;
  final List<String> _openingErrors = [];
  String? _demuxerCacheDir;

  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36';

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // ═══════════════════════════════════════════════════════
  //  生命周期
  // ═══════════════════════════════════════════════════════

  void _wireStreams() {
    _subs.addAll([
      player.stream.playing.listen((v) => playing.value = v),
      player.stream.buffering.listen((v) => buffering.value = v),
      player.stream.completed.listen((v) => completed.value = v),
      player.stream.position.listen((v) => position.value = v),
      player.stream.duration.listen((v) {
        duration.value = v;
        logger.i('player duration: $v');
      }),
      player.stream.buffer.listen((v) => buffer.value = v),
      player.stream.rate.listen((v) => speed.value = v),
      player.stream.volume.listen((v) {
        if (isDesktop) volume.value = v;
      }),
      player.stream.error.listen((e) {
        final msg = e.toString();
        if (_opening) {
          _openingErrors.add(msg);
          logger.w('PLAYER OPEN TRANSIENT ERROR: $msg');
          return;
        }
        lastError.value = msg;
        loading.value = false;
        logger.e('PLAYER ERROR: $msg');
      }),
      player.stream.log.listen((l) {
        if (kDebugMode) logger.d('mpv: $l');
      }),
    ]);
  }

  Future<void> _applyNativeTweaks() async {
    try {
      final pp = player.platform;
      if (pp is! NativePlayer) return;

      // [修复] media_kit 默认强制 cache-on-disk=yes 但不设 demuxer-cache-dir，
      // mpv 退回的默认临时目录在安卓 app 沙盒里不可写 → "Failed to create file cache"
      // → 拉流卡死拿不到首帧（PC 的默认目录可写所以没事）。显式指到 app 临时目录，
      // 对齐原版 Kazumi 的 demuxer-cache-dir 处理。
      final cacheDir = await _resolveDemuxerCacheDir();
      if (cacheDir != null) {
        await pp.setProperty('demuxer-cache-dir', cacheDir);
      }

      // 对齐 Kazumi：HLS 交给 mpv 默认策略，避免代理环境下被过短 timeout、
      // 强制低码率或手动 cache 参数干扰。
      await pp.setProperty('user-agent', _browserUserAgent);

      // ─── 平台差异 ────────────────────────────────────────────
      if (Platform.isAndroid) {
        await pp.setProperty('volume-max', '100');
      }
      logger.i('mpv native tweaks applied');
    } catch (e) {
      logger.w('native tweaks failed: $e');
    }
  }

  /// 解析并缓存 mpv 磁盘缓存目录（app 临时目录）。
  Future<String?> _resolveDemuxerCacheDir() async {
    if (_demuxerCacheDir != null) return _demuxerCacheDir;
    try {
      final dir = await getTemporaryDirectory();
      _demuxerCacheDir = dir.path;
    } catch (e) {
      logger.w('resolve demuxer cache dir failed: $e');
    }
    return _demuxerCacheDir;
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
      await player.stop();
    } catch (_) {}
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
    loading.value = true;
    lastError.value = '';
    _opening = true;
    _openingErrors.clear();
    final httpHeaders = _buildPlaybackHeaders(url, headers);
    logger.i('player.open url=$url headers=$httpHeaders');

    try {
      await _openWithRetry(
        url: url,
        headers: httpHeaders,
        startAt: startAt,
        autoPlay: autoPlay,
      );
      logger.i('player.open rendered first frame');
      await _syncSystemVolumeInitial();
      await _syncSystemBrightnessInitial();
      lastError.value = '';
      showControlsTemporarily();
    } catch (e) {
      final message = _friendlyOpenFailure(e);
      lastError.value = message;
      logger.e('open failed: $message');
    } finally {
      _opening = false;
      _openingErrors.clear();
      loading.value = false;
    }
  }

  Future<void> _openWithRetry({
    required String url,
    required Map<String, String> headers,
    required Duration startAt,
    required bool autoPlay,
  }) async {
    try {
      await _applyNativeTweaks();
      await player.open(
        Media(url, start: startAt, httpHeaders: headers),
        play: autoPlay,
      );
    } catch (e) {
      logger.w('open failed: $e');
      rethrow;
    }
  }

  Map<String, String> _buildPlaybackHeaders(
    String url,
    Map<String, String>? headers,
  ) {
    final merged = <String, String>{'User-Agent': _browserUserAgent};
    if (headers != null) {
      merged.addAll(headers);
    }
    return merged;
  }

  String _friendlyOpenFailure(Object error) {
    final raw = error.toString();
    if (error is TimeoutException || raw.contains('TimeoutException')) {
      return '起播超时：已重试 3 次仍没有首帧，建议重试或用浏览器播放';
    }
    if (raw.contains('Failed to resolve hostname') ||
        raw.contains('No address associated')) {
      return 'DNS 解析失败：当前网络找不到这个源域名，建议换源或切换网络';
    }
    if (raw.contains('403') || raw.contains('401')) {
      return '源鉴权失败：可能需要 Referer/Cookie，建议用浏览器播放或换源';
    }
    if (raw.contains('Failed to open')) {
      return '源打开失败：已重试 3 次，可能被防盗链/证书/TLS/运营商拦截';
    }
    return raw.length > 180 ? '${raw.substring(0, 180)}...' : raw;
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
      FlutterVolumeController.addListener((value) {
        if (_pendingGestureVolume != null) return;
        volume.value = (value * 100).clamp(0, 100);
      }, emitOnStart: false);
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
      milliseconds: to.inMilliseconds.clamp(
        0,
        maxMs <= 0 ? to.inMilliseconds : maxMs,
      ),
    );
    position.value = clamped;
    try {
      await player.seek(clamped);
    } catch (_) {}
  }

  Future<void> skipBy(Duration delta) async {
    await seekTo(position.value + delta);
    showControlsTemporarily();
  }

  Future<void> setSpeed(double s) async {
    speed.value = s;
    try {
      await player.setRate(s);
    } catch (_) {}
  }

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
  //  音量 / 亮度（同前）
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
    if (pending != null) await _syncSystemVolume(pending);
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

  Future<void> setBrightness(double b) async {
    final clamped = b.clamp(0.0, 1.0);
    brightness.value = clamped;
    if (isDesktop) return;
    try {
      await ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(
        clamped,
      );
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

  void updateSeekPreview({
    required int deltaMsScaled,
    required int directionSign,
  }) {
    if (directionSign != 0) seekDirection.value = directionSign;
    final maxMs = duration.value.inMilliseconds;
    final target = (seekTargetMs.value + deltaMsScaled).clamp(
      0,
      maxMs <= 0 ? seekTargetMs.value : maxMs,
    );
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
