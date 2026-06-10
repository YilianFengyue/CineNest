import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../controller/player_controller.dart';
import 'player_bottom_bar.dart';
import 'player_gesture_layer.dart';
import 'player_hud_overlays.dart';
import 'player_top_bar.dart';

/// Kazumi 风播放器视图。
///
/// **这个 widget 始终把自己铺满 parent**——上下分屏 / 全屏铺满 由外面的
/// host 用 `AspectRatio(16:9, child: ...)` 或 `Expanded(child: ...)` 决定。
class KazumiPlayerView extends StatefulWidget {
  const KazumiPlayerView({
    super.key,
    required this.controller,
    this.title,
    this.onBack,
    this.onScreenshot,
    this.onEnterPip,
    this.onRetry,
    this.onOpenInWebView,
  });

  final KazumiPlayerController controller;
  final String? title;
  final VoidCallback? onBack;
  final Future<void> Function()? onScreenshot;
  final Future<void> Function()? onEnterPip;
  final Future<void> Function()? onRetry;
  final VoidCallback? onOpenInWebView;

  @override
  State<KazumiPlayerView> createState() => _KazumiPlayerViewState();
}

class _KazumiPlayerViewState extends State<KazumiPlayerView>
    with WidgetsBindingObserver {
  KazumiPlayerController get c => widget.controller;

  Worker? _fullscreenWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 只挂一次。避免每次 build 都注册新 listener。
    _fullscreenWorker = ever<bool>(c.isFullscreen, _applySystemUiForFullscreen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applySystemUiForFullscreen(c.isFullscreen.value);
    });
  }

  @override
  void dispose() {
    _fullscreenWorker?.dispose();
    _fullscreenWorker = null;
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUi();
    super.dispose();
  }

  void _applySystemUiForFullscreen(bool full) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (full) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _restoreSystemUi() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  BoxFit _fitForAspectType(int type) {
    switch (type) {
      case 2:
        return BoxFit.cover;
      case 3:
        return BoxFit.fill;
      case 1:
      default:
        return BoxFit.contain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 视频
          Obx(
            () => Video(
              controller: c.videoController,
              controls: NoVideoControls,
              fit: _fitForAspectType(c.aspectRatioType.value),
              fill: Colors.black,
            ),
          ),

          // 2. 缓冲/加载指示器
          Obx(() {
            final showBuffering = c.loading.value || c.buffering.value;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: showBuffering ? 1 : 0,
              child: const IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),

          // 3. 手势层
          Positioned.fill(child: PlayerGestureLayer(controller: c)),

          // 4. 顶部控制栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              final visible = c.showControls.value && !c.lockPanel.value;
              final compact = !c.isFullscreen.value;
              return AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: visible ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: visible ? 1 : 0,
                  child: PlayerTopBar(
                    title: widget.title,
                    onBack: widget.onBack,
                    onEnterPip: widget.onEnterPip,
                    controller: c,
                    compact: compact,
                  ),
                ),
              );
            }),
          ),

          // 5. 底部控制栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              final visible = c.showControls.value && !c.lockPanel.value;
              final compact = !c.isFullscreen.value;
              return AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: visible ? Offset.zero : const Offset(0, 1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: visible ? 1 : 0,
                  child: PlayerBottomBar(
                    controller: c,
                    compact: compact,
                    onScreenshot: widget.onScreenshot,
                    onEnterPip: widget.onEnterPip,
                  ),
                ),
              );
            }),
          ),

          // 6. HUD 层
          Positioned.fill(child: PlayerHudOverlays(controller: c)),

          // 7. 锁定时左侧只显示解锁按钮，避免上下重复锁控件。
          Obx(() {
            if (!c.lockPanel.value) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.lock_outline),
                  onPressed: c.toggleLock,
                ),
              ),
            );
          }),

          // 8. 错误兜底
          Obx(() {
            if (c.lastError.value.isEmpty) return const SizedBox.shrink();
            return Positioned(
              left: 16,
              right: 16,
              bottom: 80,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '播放失败：${c.lastError.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          c.showControlsTemporarily();
                          widget.onRetry!();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                    if (widget.onOpenInWebView != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: widget.onOpenInWebView,
                        child: const Text('浏览器'),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
