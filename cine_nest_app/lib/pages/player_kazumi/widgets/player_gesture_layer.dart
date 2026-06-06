import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../controller/player_controller.dart';

/// 播放器手势层。
///
/// 分两层（避免 tap/long-press 与 drag 在 Flutter 手势竞技中互相吃事件）：
///
/// - 外层（铺满）：tap / double-tap / long-press（长按 2x）/ 鼠标滚轮（桌面音量）
/// - 内层（带边距，仅移动端）：
///     * 水平拖动 → seek 预览（指尖滑动只更新预览，离手才真正 seek）
///     * 垂直拖动 → 左半屏亮度 / 右半屏音量
///       缩放：亮度 height*2、音量 height*0.03（对齐 Kazumi 的手感）
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({super.key, required this.controller});

  final KazumiPlayerController controller;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  KazumiPlayerController get c => widget.controller;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  void _handleTap() {
    if (_isDesktop) {
      c.playOrPause();
    } else {
      c.toggleControls();
    }
  }

  void _handleDoubleTap() {
    if (c.lockPanel.value) return;
    if (_isDesktop) {
      c.toggleFullscreen();
    } else {
      c.playOrPause();
    }
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    c.beginLongPressSpeed();
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    c.endLongPressSpeed();
  }

  void _handlePointerScroll(PointerScrollEvent e) {
    final next = c.volume.value - e.scrollDelta.dy / 60;
    c.setVolume(next);
    c.beginVolumeGesture();
    c.finishVolumeGesture();
  }

  // ─── Drag 状态 ───────────────────────────────────────
  int _activeMode = 0; // 0=未定, 1=横滑seek, 2=左侧亮度, 3=右侧音量
  double _seekScreenWidth = 0;
  double _seekScreenHeight = 0;

  void _handleHorizontalDragStart(DragStartDetails _) {
    if (c.lockPanel.value) return;
    _activeMode = 1;
    c.pause();
    c.beginSeekPreview();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_activeMode != 1) return;
    final scale = c.gestureSeekScaleMs / _seekScreenWidth;
    final deltaMs = (details.delta.dx * scale).round();
    final dir = details.delta.dx > 0 ? 1 : (details.delta.dx < 0 ? -1 : 0);
    c.updateSeekPreview(deltaMsScaled: deltaMs, directionSign: dir);
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails _) async {
    if (_activeMode != 1) return;
    _activeMode = 0;
    await c.commitSeekPreview();
    c.play();
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (c.lockPanel.value) return;
    final isLeft = details.localPosition.dx < _seekScreenWidth / 2;
    _activeMode = isLeft ? 2 : 3;
    if (isLeft) {
      c.beginBrightnessGesture();
    } else {
      c.beginVolumeGesture();
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_activeMode == 2) {
      // 亮度
      final level = _seekScreenHeight * 2;
      final next = (c.brightness.value - details.delta.dy / level).clamp(0.0, 1.0);
      c.updateBrightnessGesture(next);
    } else if (_activeMode == 3) {
      // 音量
      final level = _seekScreenHeight * 0.03;
      final next = (c.volume.value - details.delta.dy / level).clamp(0.0, 100.0);
      c.updateVolumeGesture(next);
    }
  }

  Future<void> _handleVerticalDragEnd(DragEndDetails _) async {
    if (_activeMode == 2) {
      c.finishBrightnessGesture();
    } else if (_activeMode == 3) {
      await c.finishVolumeGesture();
    }
    _activeMode = 0;
  }

  void _handleVerticalDragCancel() {
    if (_activeMode == 2) {
      c.finishBrightnessGesture();
    } else if (_activeMode == 3) {
      c.finishVolumeGesture();
    }
    _activeMode = 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _seekScreenWidth = size.width;
    _seekScreenHeight = size.height;

    // 外层：tap/double-tap/long-press + 鼠标滚轮
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (s) {
        if (s is PointerScrollEvent && _isDesktop) _handlePointerScroll(s);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: _handleLongPressStart,
        onLongPressEnd: _handleLongPressEnd,
        child: _isDesktop
            ? const SizedBox.expand()
            : Padding(
                // 边距避免误触系统手势区
                padding: const EdgeInsets.fromLTRB(16, 25, 15, 15),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _handleHorizontalDragStart,
                  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  onVerticalDragStart: _handleVerticalDragStart,
                  onVerticalDragUpdate: _handleVerticalDragUpdate,
                  onVerticalDragEnd: _handleVerticalDragEnd,
                  onVerticalDragCancel: _handleVerticalDragCancel,
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}
