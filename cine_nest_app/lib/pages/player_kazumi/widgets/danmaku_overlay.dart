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

  // 按 timeMs 升序的快照 + 单调推进的游标，
  // 每个 position tick 只扫新增区间，避免全量 O(N) 遍历。
  List<DanDanComment> _sorted = const [];
  int _cursor = 0;
  int _lastDispatchMs = -1;
  bool _seeked = false;

  @override
  void initState() {
    super.initState();
    // 全屏切换会重建本 State，弹幕可能早已加载，先吃一次现有数据
    _resetDispatch();
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
    _sorted = List.of(c.danmakuItems)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _cursor = 0;
    _lastDispatchMs = -1;
    _seeked = true;
    _danmakuCtrl?.clear();
  }

  void _onPositionChanged(Duration pos) {
    final ctrl = _danmakuCtrl;
    if (ctrl == null) return;
    if (!c.danmakuVisible.value) return;
    if (_sorted.isEmpty) return;

    final nowMs = pos.inMilliseconds;

    // 首次 or seek 跳跃 → 二分重定位游标
    if (_seeked ||
        _lastDispatchMs < 0 ||
        (nowMs - _lastDispatchMs).abs() > 1500) {
      _seeked = false;
      ctrl.clear();
      _cursor = _lowerBound(nowMs);
      _lastDispatchMs = nowMs;
      return;
    }

    if (nowMs <= _lastDispatchMs) return;
    _lastDispatchMs = nowMs;

    // 游标单调推进，只扫这一帧新增的时间区间
    while (_cursor < _sorted.length && _sorted[_cursor].timeMs <= nowMs) {
      _addDanmaku(ctrl, _sorted[_cursor]);
      _cursor++;
    }
  }

  /// 第一个 timeMs > [ms] 的下标。
  int _lowerBound(int ms) {
    var lo = 0;
    var hi = _sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_sorted[mid].timeMs <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _addDanmaku(DanmakuController ctrl, DanDanComment item) {
    // 彩色弹幕屏蔽（非白色 = 彩色）
    if (c.danmakuHideColor.value && (item.color & 0x00FFFFFF) != 0x00FFFFFF) {
      return;
    }
    // 高级弹幕屏蔽（非标准 1/4/5 模式）
    if (c.danmakuHideAdvanced.value &&
        item.mode != 1 && item.mode != 4 && item.mode != 5) {
      return;
    }
    // 密度过滤：确定性哈希采样，同一条弹幕永远显示/隐藏，seek 不闪烁
    final density = c.danmakuDensity.value;
    if (density < 1.0 &&
        item.content.hashCode.abs() % 100 >= (density * 100).round()) {
      return;
    }

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
