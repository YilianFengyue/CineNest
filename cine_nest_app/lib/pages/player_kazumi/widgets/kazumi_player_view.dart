import 'dart:async';
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

/// 整个 Kazumi 风格播放器的视图根节点。
///
/// 结构（Stack 自底向上）：
///   1. Video 渲染面（按 aspectRatioType 适配）
///   2. 缓冲/加载指示器
///   3. 手势层（tap/double-tap/long-press + 横滑 seek/竖滑 vol/亮度）
///   4. 顶部控制栏（标题 + 锁 + 设置）
///   5. 底部控制栏（播放/进度/时间/全屏/截图/PIP）
///   6. HUD 层（vol/亮度/倍速/seek 预览）
class KazumiPlayerView extends StatefulWidget {
  const KazumiPlayerView({
    super.key,
    required this.controller,
    this.title,
    this.onBack,
    this.onScreenshot,
    this.onEnterPip,
  });

  final KazumiPlayerController controller;
  final String? title;
  final VoidCallback? onBack;

  /// 截图按钮回调；默认走 controller.screenshot() + saver_gallery 保存
  final Future<void> Function()? onScreenshot;

  /// PIP 按钮回调；默认走 floating 包
  final Future<void> Function()? onEnterPip;

  @override
  State<KazumiPlayerView> createState() => _KazumiPlayerViewState();
}

class _KazumiPlayerViewState extends State<KazumiPlayerView>
    with WidgetsBindingObserver {
  KazumiPlayerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUiIfNeeded();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切后台时停止播放（后台播放由 audio_service 接管，Step 1 先用最简单策略）
    if (state == AppLifecycleState.paused && c.playing.value) {
      // 后续若开启后台播放开关，这里跳过暂停；当前默认暂停
      // c.pause();
    }
  }

  void _applySystemUiForFullscreen(bool full) {
    if (Platform.isAndroid || Platform.isIOS) {
      if (full) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    }
  }

  void _restoreSystemUiIfNeeded() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
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
    // 监听全屏切换，套用系统 UI
    ever<bool>(c.isFullscreen, _applySystemUiForFullscreen);

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 视频
          Obx(() => Video(
                controller: c.videoController,
                controls: NoVideoControls,
                fit: _fitForAspectType(c.aspectRatioType.value),
                fill: Colors.black,
              )),

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

          // 3. 手势层（包含 tap/double-tap/long-press/drag）
          Positioned.fill(
            child: PlayerGestureLayer(controller: c),
          ),

          // 4. 顶部控制栏
          Obx(() {
            final visible = c.showControls.value && !c.lockPanel.value;
            return AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: visible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: visible ? 1 : 0,
                child: PlayerTopBar(
                  title: widget.title,
                  onBack: widget.onBack,
                  controller: c,
                ),
              ),
            );
          }),

          // 5. 底部控制栏
          Obx(() {
            final visible = c.showControls.value && !c.lockPanel.value;
            return Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: visible ? Offset.zero : const Offset(0, 1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: visible ? 1 : 0,
                  child: PlayerBottomBar(
                    controller: c,
                    onScreenshot: widget.onScreenshot,
                    onEnterPip: widget.onEnterPip,
                  ),
                ),
              ),
            );
          }),

          // 6. HUD 层
          Positioned.fill(child: PlayerHudOverlays(controller: c)),

          // 7. 锁定时只显示一个解锁按钮
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
        ],
      ),
    );
  }
}
