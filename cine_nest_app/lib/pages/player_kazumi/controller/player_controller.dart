import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

import '../../../services/dandanplay_service.dart';
import '../../../services/logvar_danmu_service.dart';
import '../../../services/logger.dart';
import '../../../services/shader_asset_service.dart';
import '../../../utils/storage_pref.dart';

/// 播放器核心控制器（GetX 包装 media_kit Player + VideoController）。
class KazumiPlayerController extends GetxController {
  KazumiPlayerController({
    this.bufferSizeBytes = 512 * 1024 * 1024,
    this.firstFrameTimeout = const Duration(seconds: 12),
    this.stallTimeout = const Duration(seconds: 10),
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

  /// 起播后等首个流参数（时长/视频尺寸）的超时，超时自动重开。
  final Duration firstFrameTimeout;

  /// 播放中持续缓冲多久仍无进展，判定为致命卡死。
  final Duration stallTimeout;
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

  /// 超分辨率档位: 1=关, 2=效率, 3=质量
  final superResolution = 1.obs;

  // ─── 弹幕状态 ─────────────────────────────────────────
  final danmakuVisible = true.obs;
  final danmakuOpacity = 1.0.obs;
  final danmakuFontScale = 1.0.obs;
  final danmakuArea = 0.8.obs;
  final danmakuDuration = 8.0.obs;
  final danmakuHideScroll = false.obs;
  final danmakuHideTop = false.obs;
  final danmakuHideBottom = false.obs;
  final danmakuMassive = false.obs;
  final danmakuDensity = 1.0.obs;
  final danmakuHideColor = false.obs;
  final danmakuHideAdvanced = false.obs;
  final danmakuLoading = false.obs;
  final danmakuItems = <DanDanComment>[].obs;
  final danmakuCount = 0.obs;

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

  /// 瞬态提示（网络波动等，自动消失，播放未中断）。
  final transientHint = ''.obs;

  /// 致命错误（播放确实进行不下去了，需要用户重试/换源/浏览器）。
  final fatalError = ''.obs;

  // ─── 内部 ─────────────────────────────────────────────
  final List<StreamSubscription> _subs = [];
  Timer? _hideTimer;
  Timer? _hudHideTimer;
  Timer? _volumeGestureSyncTimer;
  Timer? _hintHideTimer;
  Timer? _stallTimer;
  double? _pendingGestureVolume;
  double _savedSpeedBeforeLongPress = 1.0;
  bool _opening = false;
  bool _resumeAfterSeekPreview = false;
  final List<String> _openingErrors = [];
  String? _demuxerCacheDir;

  // 最近一次 open 的参数，供「重试」从当前位置重开
  String? _lastOpenUrl;
  Map<String, String>? _lastOpenHeaders;
  Duration _lastOpenStartAt = Duration.zero;

  static const int _maxOpenAttempts = 2;

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
      player.stream.buffering.listen((v) {
        buffering.value = v;
        // 播放途中陷入缓冲 → 启动卡死看门狗；恢复 → 解除（含误报的致命提示）
        if (v) {
          _startStallWatchdog();
        } else {
          _cancelStallWatchdog();
          if (!_opening && fatalError.value.isNotEmpty) {
            fatalError.value = '';
          }
        }
      }),
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
      // media_kit 的 error 流本质是 mpv 的 error 级日志（含每条 tcp: 分片失败），
      // 大多是 ffmpeg 重连可自愈的瞬态错误，不能当「播放失败」处理。
      // 真正的致命判定交给卡死看门狗（缓冲持续无进展）和起播超时。
      player.stream.error.listen((e) {
        final msg = e.toString();
        if (_opening) {
          _openingErrors.add(msg);
          logger.w('PLAYER OPEN TRANSIENT ERROR: $msg');
          return;
        }
        logger.w('PLAYER STREAM ERROR: $msg');
        if (_isNetworkNoise(msg)) {
          _showTransientHint('网络波动，自动重连中…');
        }
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

      // 分片中途 TCP 读失败时 ffmpeg 默认直接断流报错；开启 reconnect 后
      // 改为带退避自动重连续读，配合大 demuxer 缓存把 CDN 抖动变成无感恢复。
      // 注意：这个属性是整串覆盖，必须把 media_kit 的默认参数一并带上——
      // seg_max_retry（HLS 分片级重试）/ allowed_extensions=ALL（伪装 .jpg
      // 等扩展名的分片）/ protocol_whitelist 含 crypto（AES-128 加密流），
      // 丢任何一个都会让一类源直接播不了或抖动时更易断流。
      await pp.setProperty(
        'demuxer-lavf-o',
        'reconnect=1,reconnect_streamed=1,'
        'reconnect_on_network_error=1,reconnect_delay_max=5,'
        'seg_max_retry=5,strict=experimental,allowed_extensions=ALL,'
        'protocol_whitelist=[udp,rtp,tcp,tls,data,file,http,https,crypto]',
      );
      // media_kit 默认 network-timeout=5s，对慢源偏紧（误杀正常的慢分片）；
      // 放宽到 8s：半死连接最迟 8s 被掐死、交给上面的 reconnect 接管。
      await pp.setProperty('network-timeout', '8');

      // ─── 平台差异 ────────────────────────────────────────────
      if (Platform.isAndroid) {
        await pp.setProperty('volume-max', '100');
      }
      logger.i('mpv native tweaks applied');
    } catch (e) {
      logger.w('native tweaks failed: $e');
    }
  }

  /// Anime4K 超分辨率：1=关, 2=效率(Lite), 3=质量(Full)
  Future<void> setShader(int type) async {
    try {
      final pp = player.platform;
      if (pp is! NativePlayer) return;
      // 对齐原版 Kazumi：等 mpv 和渲染上下文就绪再下发 shader 命令，
      // 避免初始化竞态导致命令丢失（设了档位但画面没变化）
      await pp.waitForPlayerInitialization;
      await pp.waitForVideoControllerInitializationIfAttached;
      final svc = ShaderAssetService.instance;
      await svc.ensureShadersCopied();
      if (type == 2) {
        await pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          buildShadersPath(svc.shadersPath, kAnime4KShadersLite),
        ]);
      } else if (type == 3) {
        await pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          buildShadersPath(svc.shadersPath, kAnime4KShaders),
        ]);
      } else {
        await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
      }
      superResolution.value = type;
      logger.i('Anime4K shader set to type=$type');
    } catch (e) {
      logger.w('setShader failed: $e');
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
    _cancelHintHideTimer();
    _cancelStallWatchdog();
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
    _clearErrors();
    _cancelStallWatchdog();
    _opening = true;
    _openingErrors.clear();
    _lastOpenUrl = url;
    _lastOpenHeaders = headers;
    _lastOpenStartAt = startAt;
    final httpHeaders = _buildPlaybackHeaders(url, headers);
    logger.i('player.open url=$url headers=$httpHeaders');

    try {
      // 对齐原版 Kazumi：起播前恢复用户已选的超分档位
      //（glsl-shaders 属性跨 loadfile 持久，但换源/重建后需重设保险）
      if (superResolution.value > 1) {
        await setShader(superResolution.value);
      }
      await _openWithRetry(
        url: url,
        headers: httpHeaders,
        startAt: startAt,
        autoPlay: autoPlay,
      );
      logger.i('player.open stream ready (got duration/video params)');
      await _syncSystemVolumeInitial();
      await _syncSystemBrightnessInitial();
      _clearErrors();
      showControlsTemporarily();
    } catch (e) {
      final message = _friendlyOpenFailure(e);
      fatalError.value = message;
      logger.e('open failed: $message');
    } finally {
      _opening = false;
      _openingErrors.clear();
      loading.value = false;
    }
  }

  /// 致命错误后的「重试」：从当前播放位置重开最后一次打开的媒体。
  Future<void> retryFromCurrentPosition() async {
    final url = _lastOpenUrl;
    if (url == null) return;
    final resumeAt =
        position.value > Duration.zero ? position.value : _lastOpenStartAt;
    await open(url: url, headers: _lastOpenHeaders, startAt: resumeAt);
  }

  Future<void> _openWithRetry({
    required String url,
    required Map<String, String> headers,
    required Duration startAt,
    required bool autoPlay,
  }) async {
    Object lastFailure = TimeoutException('open failed');
    for (var attempt = 1; attempt <= _maxOpenAttempts; attempt++) {
      try {
        await _applyNativeTweaks();
        // 先挂流参数监听再 open，避免事件比订阅先到
        final streamReady = _waitStreamReady(firstFrameTimeout);
        try {
          await player.open(
            Media(url, start: startAt, httpHeaders: headers),
            play: autoPlay,
          );
        } catch (_) {
          streamReady.ignore(); // 监听随超时自清理，错误不外漏
          rethrow;
        }
        // player.open 返回只代表 loadfile 已提交；等拿到时长/视频尺寸
        // 才算真正起播，否则死源会表现为无限转圈。
        await streamReady;
        return;
      } catch (e) {
        lastFailure = e;
        logger.w('open attempt $attempt/$_maxOpenAttempts failed: $e');
        if (attempt < _maxOpenAttempts) {
          try {
            await player.stop();
          } catch (_) {}
        }
      }
    }
    throw lastFailure;
  }

  /// 等首个有效流参数（时长 > 0 或视频宽度 > 0），超时报 TimeoutException。
  Future<void> _waitStreamReady(Duration timeout) {
    final completer = Completer<void>();
    final subs = <StreamSubscription>[];
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('${timeout.inSeconds}s 内未拿到流参数'),
        );
      }
    });
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    subs.add(player.stream.duration.listen((d) {
      if (d > Duration.zero) done();
    }));
    subs.add(player.stream.width.listen((w) {
      if ((w ?? 0) > 0) done();
    }));
    return completer.future.whenComplete(() {
      timer.cancel();
      for (final s in subs) {
        s.cancel();
      }
    });
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
    // 起播期间收集到的 mpv 错误日志里往往藏着真实原因（DNS/403 等）
    final raw = '$error ${_openingErrors.join('; ')}';
    if (raw.contains('Failed to resolve hostname') ||
        raw.contains('No address associated')) {
      return 'DNS 解析失败：当前网络找不到这个源域名，建议换源或切换网络';
    }
    if (raw.contains('403') || raw.contains('401')) {
      return '源鉴权失败：可能需要 Referer/Cookie，建议用浏览器播放或换源';
    }
    if (error is TimeoutException || raw.contains('TimeoutException')) {
      return '起播超时：已自动重试 $_maxOpenAttempts 次仍没有画面，'
          '建议重试、换源或用浏览器播放';
    }
    if (raw.contains('Failed to open')) {
      return '源打开失败：可能被防盗链/证书/TLS/运营商拦截，建议换源';
    }
    final msg = error.toString();
    return msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
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

  /// 进入 seek 预览：记住原播放状态并暂停，commit/cancel 时按原状态恢复，
  /// 用户暂停时拖进度条不会被强制开播。
  void beginSeekPreview() {
    _resumeAfterSeekPreview = playing.value;
    pause();
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
    if (_resumeAfterSeekPreview) {
      _resumeAfterSeekPreview = false;
      await play();
    }
    _startHideTimer();
  }

  void cancelSeekPreview() {
    showSeekHud.value = false;
    seekDirection.value = 0;
    if (_resumeAfterSeekPreview) {
      _resumeAfterSeekPreview = false;
      play();
    }
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

  /// tcp/DNS/HTTP 类错误日志：reconnect 大概率自愈，只配低调提示。
  bool _isNetworkNoise(String msg) {
    final m = msg.toLowerCase();
    return m.startsWith('tcp') ||
        m.startsWith('http') ||
        m.contains('failed to resolve hostname') ||
        m.contains('no address associated') ||
        m.contains('connection') ||
        m.contains('timed out') ||
        m.contains('network');
  }

  void _showTransientHint(String message) {
    // 致命错误展示中不再叠加瞬态提示
    if (fatalError.value.isNotEmpty) return;
    _cancelHintHideTimer();
    transientHint.value = message;
    _hintHideTimer = Timer(const Duration(seconds: 3), () {
      if (transientHint.value == message) {
        transientHint.value = '';
      }
    });
  }

  void _clearErrors() {
    _cancelHintHideTimer();
    transientHint.value = '';
    fatalError.value = '';
  }

  void _cancelHintHideTimer() {
    _hintHideTimer?.cancel();
    _hintHideTimer = null;
  }

  /// 卡死看门狗：缓冲持续 [stallTimeout] 且位置毫无进展，才升级为致命错误。
  void _startStallWatchdog() {
    if (_opening) return; // 起播阶段由首帧超时负责
    _cancelStallWatchdog();
    final posAtStart = position.value;
    _stallTimer = Timer(stallTimeout, () {
      if (buffering.value && position.value == posAtStart) {
        transientHint.value = '';
        fatalError.value =
            '网络持续无响应：缓冲超过 ${stallTimeout.inSeconds} 秒没有恢复，'
            '可重试或用浏览器播放';
      }
    });
  }

  void _cancelStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = null;
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

  // ═══════════════════════════════════════════════════════
  //  弹幕
  // ═══════════════════════════════════════════════════════

  void loadDanmakuPrefs() {
    danmakuVisible.value = Pref.danmakuEnabled;
    danmakuOpacity.value = Pref.danmakuOpacity;
    danmakuFontScale.value = Pref.danmakuFontScale;
    danmakuArea.value = Pref.danmakuArea;
    danmakuDuration.value = Pref.danmakuDuration;
    danmakuHideScroll.value = Pref.danmakuHideScroll;
    danmakuHideTop.value = Pref.danmakuHideTop;
    danmakuHideBottom.value = Pref.danmakuHideBottom;
    danmakuMassive.value = Pref.danmakuMassive;
    danmakuDensity.value = Pref.danmakuDensity;
    danmakuHideColor.value = Pref.danmakuHideColor;
    danmakuHideAdvanced.value = Pref.danmakuHideAdvanced;
  }

  void toggleDanmaku() {
    danmakuVisible.value = !danmakuVisible.value;
    Pref.setDanmakuEnabled(danmakuVisible.value);
  }

  final _dandanService = DanDanPlayService();
  final _logvarService = LogvarDanmuService();

  DanmakuSource get _danmakuSource =>
      Pref.danmakuSource == 'dandanplay' ? _dandanService : _logvarService;

  Future<void> fetchDanmaku({
    required String title,
    int? tmdbId,
    int? episodeNumber,
  }) async {
    final source = _danmakuSource;
    if (!source.hasCredentials) return;
    danmakuLoading.value = true;
    try {
      final items = await source.fetchDanmaku(
        title: title,
        tmdbId: tmdbId,
        episodeNumber: episodeNumber,
      );
      danmakuItems.value = items;
      danmakuCount.value = items.length;
    } catch (e) {
      logger.w('fetchDanmaku failed: $e');
    } finally {
      danmakuLoading.value = false;
    }
  }
}
