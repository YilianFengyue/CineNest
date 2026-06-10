import 'package:flutter/material.dart';

/// 配色方案候选色（原封照搬 Kazumi `lib/bean/settings/color_type.dart`）。
///
/// 第 0 项「默认」既是默认种子也是重置项；其余为可选品牌色。
final List<Map<String, dynamic>> colorThemeTypes = [
  {'color': Colors.green, 'label': '默认'},
  {'color': Colors.teal, 'label': '青色'},
  {'color': Colors.blue, 'label': '蓝色'},
  {'color': Colors.indigo, 'label': '靛蓝色'},
  {'color': const Color(0xff6750a4), 'label': '紫罗兰色'},
  {'color': Colors.pink, 'label': '粉红色'},
  {'color': Colors.yellow, 'label': '黄色'},
  {'color': Colors.orange, 'label': '橙色'},
  {'color': Colors.deepOrange, 'label': '深橙色'},
];
