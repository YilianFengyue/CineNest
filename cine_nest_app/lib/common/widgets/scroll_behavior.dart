import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// 自定义滚动行为（移植自 PiliPlus）：隐藏滚动条 + 多指针拖拽支持。
class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior([this.dragDevices = _defaultDragDevices]);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  final Set<PointerDeviceKind> dragDevices;
}

const Set<PointerDeviceKind> _defaultDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
  PointerDeviceKind.mouse,
};
