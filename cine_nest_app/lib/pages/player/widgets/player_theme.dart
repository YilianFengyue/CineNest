import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'player_chrome.dart';
import 'player_hud.dart';

/// 给 [Video] 套的两套 chrome 主题：
/// - normal: 在详情页 16:9 内联
/// - fullscreen: 横屏全屏
///
/// 手势、双击 seek、长按 2x、亮度/音量、淡入淡出、全屏路由全部交给 [MaterialVideoControls]
/// 自己处理；我们只换衣服（颜色 + 顶/底栏内容 + 5 个 HUD 样式）。
MaterialVideoControlsThemeData buildPlayerTheme({
  required BuildContext context,
  required bool fullscreen,
  required PlayerActions actions,
}) {
  final cs = Theme.of(context).colorScheme;

  final buttonBarHeight = fullscreen ? 56.0 : 44.0;
  final buttonBarBottom = fullscreen ? 24.0 : 8.0;
  // 进度条独立到按钮栏正上方一行，不再和按钮挤一坨
  final seekBarBottom = buttonBarBottom + buttonBarHeight - 4;

  return MaterialVideoControlsThemeData(
    // 手势全开
    volumeGesture: true,
    brightnessGesture: true,
    seekGesture: true,
    seekOnDoubleTap: true,
    seekOnDoubleTapEnabledWhileControlsVisible: true,
    seekOnDoubleTapBackwardDuration: const Duration(seconds: 10),
    seekOnDoubleTapForwardDuration: const Duration(seconds: 10),
    speedUpOnLongPress: true,
    speedUpFactor: 2.0,
    gesturesEnabledWhileControlsVisible: true,

    // 控件淡入淡出
    controlsHoverDuration: const Duration(seconds: 3),
    controlsTransitionDuration: const Duration(milliseconds: 250),
    backdropColor: cs.scrim.withValues(alpha: fullscreen ? 0.55 : 0.4),

    // 自定义 HUD（M3 药丸）
    bufferingIndicatorBuilder: buildBufferingIndicator,
    volumeIndicatorBuilder: buildVolumeIndicator,
    brightnessIndicatorBuilder: buildBrightnessIndicator,
    seekIndicatorBuilder: buildSeekIndicator,
    speedUpIndicatorBuilder: buildSpeedUpIndicator,

    // 按钮栏
    buttonBarHeight: buttonBarHeight,
    buttonBarButtonSize: fullscreen ? 24.0 : 22.0,
    buttonBarButtonColor: Colors.white,
    primaryButtonBar: const [
      Spacer(),
      MaterialPlayOrPauseButton(iconSize: 64),
      Spacer(),
    ],
    // inline 已有 AppBar 顶栏，避免重复；fullscreen 才需要播放器顶栏
    topButtonBar:
        fullscreen ? buildTopButtonBar(context, actions) : const <Widget>[],
    topButtonBarMargin: EdgeInsets.fromLTRB(
      fullscreen ? 12 : 8,
      8,
      fullscreen ? 12 : 8,
      0,
    ),
    bottomButtonBar: fullscreen
        ? buildBottomButtonBarFullscreen(context, actions)
        : buildBottomButtonBarInline(context, actions),
    bottomButtonBarMargin: EdgeInsets.fromLTRB(
      fullscreen ? 16 : 8,
      0,
      fullscreen ? 16 : 8,
      buttonBarBottom,
    ),

    // 进度条
    displaySeekBar: true,
    seekBarMargin: EdgeInsets.only(
      left: fullscreen ? 16 : 12,
      right: fullscreen ? 16 : 12,
      bottom: seekBarBottom,
    ),
    seekBarHeight: fullscreen ? 4 : 3.5,
    seekBarContainerHeight: 28,
    seekBarColor: Colors.white.withValues(alpha: 0.24),
    seekBarPositionColor: cs.primary,
    seekBarBufferColor: cs.primary.withValues(alpha: 0.4),
    seekBarThumbColor: cs.primary,
    seekBarThumbSize: fullscreen ? 16 : 14,
    seekBarAlignment: Alignment.bottomCenter,
  );
}
