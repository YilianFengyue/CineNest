import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/dandanplay_service.dart';
import '../controller/player_controller.dart';

/// 弹幕渲染层——叠在视频上方、手势层下方。
///
/// DanmakuScreen 只创建一次，设置变更走 `updateOption`，
/// 不在 Obx 里 rebuild 以免丢失弹幕状态。
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({super.key, required this.controller});

  final KazumiPlayerController controller;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> {
  KazumiPlayerController get c => widget.controller;

  DanmakuController? _danmakuCtrl;
  final List<Worker> _workers = [];

  int _lastDispatchMs = -1;
  bool _seeked = false;

  @override
  void initState() {
    super.initState();
    _workers.addAll([
      ever<Duration>(c.position, _onPositionChanged),
      ever<bool>(c.playing, _onPlayingChanged),
      ever<List<DanDanComment>>(c.danmakuItems, (_) => _resetDispatch()),
      // 设置变更 → updateOption
      ever<double>(c.danmakuOpacity, (_) => _syncOption()),
      ever<double>(c.danmakuFontScale, (_) => _syncOption()),
      ever<double>(c.danmakuArea, (_) => _syncOption()),
      ever<double>(c.danmakuDuration, (_) => _syncOption()),
      ever<bool>(c.danmakuHideScroll, (_) => _syncOption()),
      ever<bool>(c.danmakuHideTop, (_) => _syncOption()),
      ever<bool>(c.danmakuHideBottom, (_) => _syncOption()),
      ever<bool>(c.danmakuMassive, (_) => _syncOption()),
    ]);
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _workers.clear();
    super.dispose();
  }

  DanmakuOption _buildOption() {
    return DanmakuOption(
      fontSize: 16 * c.danmakuFontScale.value,
      duration: c.danmakuDuration.value,
      opacity: c.danmakuOpacity.value,
      area: c.danmakuArea.value,
      hideTop: c.danmakuHideTop.value,
      hideBottom: c.danmakuHideBottom.value,
      hideScroll: c.danmakuHideScroll.value,
      massiveMode: c.danmakuMassive.value,
    );
  }

  void _syncOption() {
    _danmakuCtrl?.updateOption(_buildOption());
  }

  void _resetDispatch() {
    _lastDispatchMs = -1;
    _seeked = true;
    _danmakuCtrl?.clear();
  }

  void _onPositionChanged(Duration pos) {
    final ctrl = _danmakuCtrl;
    if (ctrl == null) return;
    if (!c.danmakuVisible.value) return;

    final nowMs = pos.inMilliseconds;
    final items = c.danmakuItems;
    if (items.isEmpty) return;

    // 首次 or seek 跳跃 → 重置指针
    if (_seeked || _lastDispatchMs < 0 || (nowMs - _lastDispatchMs).abs() > 1500) {
      _seeked = false;
      ctrl.clear();
      _lastDispatchMs = nowMs;
      return;
    }

    final fromMs = _lastDispatchMs;
    final toMs = nowMs;
    _lastDispatchMs = nowMs;

    if (toMs <= fromMs) return;

    for (final item in items) {
      if (item.timeMs > fromMs && item.timeMs <= toMs) {
        _addDanmaku(ctrl, item);
      }
    }
  }

  void _addDanmaku(DanmakuController ctrl, DanDanComment item) {
    DanmakuItemType type;
    switch (item.mode) {
      case 4:
        type = DanmakuItemType.bottom;
        break;
      case 5:
        type = DanmakuItemType.top;
        break;
      default:
        type = DanmakuItemType.scroll;
    }
    ctrl.addDanmaku(DanmakuContentItem(
      item.content,
      color: Color(item.color),
      type: type,
    ));
  }

  void _onPlayingChanged(bool playing) {
    final ctrl = _danmakuCtrl;
    if (ctrl == null) return;
    if (playing) {
      ctrl.resume();
    } else {
      ctrl.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = c.danmakuVisible.value && c.danmakuItems.isNotEmpty;
      return IgnorePointer(
        child: Opacity(
          opacity: visible ? 1.0 : 0.0,
          child: DanmakuScreen(
            createdController: (ctrl) {
              _danmakuCtrl = ctrl;
              _syncOption();
              if (!c.playing.value) ctrl.pause();
            },
            option: _buildOption(),
          ),
        ),
      );
    });
  }
}
