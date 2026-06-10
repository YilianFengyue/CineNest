import 'package:flutter/material.dart';

/// Agent 工具 → 数据来源的展示映射（成员 C · F9）。
///
/// 后端注册了 8 个工具，这里把它们归类到用户可感知的「来源」，
/// 在对话状态条上以 chip 呈现「Agent 正在/已经查了哪些源」。
///
/// 已实现来源：资源库（20 个 MacCMS 站）、影视资料（豆瓣，TMDB 需 Token）、智能推荐、互动海报。
/// 规划中来源（置灰占位）：番剧库 / B站 / 网盘·PC。
class ToolSource {
  final String label;
  final IconData icon;

  /// 是否已实现（false 则 chip 置灰，标注「即将支持」）。
  final bool implemented;

  const ToolSource({
    required this.label,
    required this.icon,
    this.implemented = true,
  });

  /// 按后端工具名归类。
  static ToolSource of(String toolName) {
    switch (toolName) {
      case 'search_playable_resources':
      case 'get_playable_resource_detail':
      case 'build_microdesign_posts':
        return const ToolSource(label: '资源库', icon: Icons.movie_filter_outlined);
      case 'browse_catalog_hot':
      case 'search_catalog_movies':
        return const ToolSource(label: '豆瓣 / TMDB', icon: Icons.local_movies_outlined);
      case 'build_recommendation_feed':
        return const ToolSource(label: '智能推荐', icon: Icons.auto_awesome_outlined);
      case 'build_catalog_microdesign_poster':
        return const ToolSource(label: '互动海报', icon: Icons.dashboard_customize_outlined);
      case 'get_backend_status':
        return const ToolSource(label: '系统状态', icon: Icons.tune_outlined);
      default:
        return ToolSource(label: toolName, icon: Icons.extension_outlined);
    }
  }

  /// 规划中的来源（用于在「能力」入口展示全景，置灰占位）。
  static const List<ToolSource> upcoming = [
    ToolSource(label: '番剧库', icon: Icons.subscriptions_outlined, implemented: false),
    ToolSource(label: 'B 站解说', icon: Icons.smart_display_outlined, implemented: false),
    ToolSource(label: '网盘 · PC', icon: Icons.cloud_outlined, implemented: false),
  ];
}
