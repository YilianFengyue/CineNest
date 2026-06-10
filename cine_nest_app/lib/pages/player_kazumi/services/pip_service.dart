import 'dart:io';

import 'package:floating/floating.dart';

/// Android 画中画（PIP）包装。其它平台返回 false。
///
/// 用法：在播放器顶层 Stack 外面套 `PiPSwitcher.childWhenDisabled` 才能在 PIP
/// 模式下隐藏控件 —— Step 1 先只暴露进入 PIP 的入口，后续接 UI 切换。
class PipService {
  PipService._();

  static final Floating _floating = Floating();

  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _floating.isPipAvailable;
    } catch (_) {
      return false;
    }
  }

  /// 进入 PIP。可选传入视频画面比例（默认 16:9）。
  static Future<bool> enter({int aspectWidth = 16, int aspectHeight = 9}) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _floating.enable(
        ImmediatePiP(aspectRatio: Rational(aspectWidth, aspectHeight)),
      );
      return result == PiPStatus.enabled;
    } catch (_) {
      return false;
    }
  }
}
