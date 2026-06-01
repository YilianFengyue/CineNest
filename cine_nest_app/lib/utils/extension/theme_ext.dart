import 'package:flutter/material.dart' show ThemeData, Color, ColorScheme, Brightness, Colors;

/// 主题相关扩展（移植自 PiliPlus，剔除 B站 vip/大会员配色）。
extension ThemeDataExt on ThemeData {
  bool get isLight => brightness == Brightness.light;
  bool get isDark => brightness == Brightness.dark;
}

extension ColorSchemeExt on ColorScheme {
  bool get isLight => brightness == Brightness.light;
  bool get isDark => brightness == Brightness.dark;
}

extension ColorExtension on Color {
  /// 向黑色插值，用于纯黑主题加深。
  Color darken([double amount = .5]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(this, Colors.black, amount)!;
  }
}

extension BrightnessExt on Brightness {
  Brightness get reverse =>
      this == Brightness.light ? Brightness.dark : Brightness.light;
  bool get isLight => this == Brightness.light;
  bool get isDark => this == Brightness.dark;
}
