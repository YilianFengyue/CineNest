import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:cine_nest/pages/feed/discovery/discovery_view.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_history_page.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_favorites_page.dart';
import 'package:cine_nest/pages/settings/appearance_settings_page.dart';
import 'package:cine_nest/pages/settings/agent_profile_page.dart';
import 'package:cine_nest/pages/settings/connection_settings_page.dart';
import 'package:cine_nest/pages/settings/dandanplay_settings_page.dart';
import 'package:cine_nest/pages/settings/playback_settings_page.dart';
import 'package:cine_nest/pages/settings/placeholder_settings_page.dart';
import 'package:cine_nest/pages/settings/taste_settings_page.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 设置页（Tab 3）。
///
/// 结构照搬 Kazumi 的 `lib/pages/my/my_page.dart`：分组卡片 + 导航 tile，
/// 用 `card_settings_ui` 的 [SettingsList] / [SettingsSection] /
/// [SettingsTile]。内容替换成 CineNest 自己的功能：
/// - 已实现的（观影历史 / 我的收藏 / 口味偏好 / PC 连接 / 外观）直接接真实页；
/// - 还没做的（播放设置 / 视频源规则 / 下载管理 / 界面设置 / 关于）先用
///   [PlaceholderSettingsPage] 占位，把入口跑通，后续替换即可。
///
/// 顶部预留了「用户画像卡」槽位 [_buildProfileHeader]，现在返回空占位，
/// 后续要加时把卡片塞进去即可，无需改动下方列表结构。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsList(
      maxWidth: 1000,
      sections: [
        // ── 顶部：用户画像卡槽位（预留，后续接入）──
        CustomSettingsSection(child: _buildProfileHeader(context)),

        // ── 我的（已迁移的既有功能）──
        SettingsSection(
          title: const Text('我的'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.history_rounded),
              title: const Text('观影历史'),
              description: const Text('本地观看记录'),
              onPressed: (_) => Get.to(() => const KazumiHistoryPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('我的收藏'),
              description: const Text('本地收藏的影片'),
              onPressed: (_) => Get.to(() => const KazumiFavoritesPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('口味偏好'),
              description: const Text('设置喜欢 / 不喜欢的类型，影响推荐'),
              onPressed: (_) => Get.to(() => const TasteSettingsPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.psychology_alt_rounded),
              title: const Text('Agent 长期画像'),
              description: const Text('同步本地历史收藏，查看画像图表数据'),
              onPressed: (_) => Get.to(() => const AgentProfilePage()),
            ),
          ],
        ),

        // ── 播放与资源（成员 A 的领地，多数待接入）──
        SettingsSection(
          title: const Text('播放与资源'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('播放器测试 (Kazumi 风)'),
              description: const Text('贴 m3u8 / mp4 / 选本地视频，验证播放器'),
              onPressed: (_) => Get.toNamed(Routes.kazumiPlayerTest),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('聚合器 Temple'),
              description: const Text('MoonTV 风本地聚合搜索、详情、试播'),
              onPressed: (_) => Get.toNamed(Routes.aggregatorTemple),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.display_settings_rounded),
              title: const Text('播放设置'),
              description: const Text('TMDB 源管理、播放器参数'),
              onPressed: (_) =>
                  Get.to(() => const PlaybackSettingsPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.extension_rounded),
              title: const Text('视频源规则'),
              description: const Text('管理影视资源解析规则'),
              onPressed: (_) => _openPlaceholder(
                title: '视频源规则',
                icon: Icons.extension_rounded,
                owner: 'Member A',
              ),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.download_rounded),
              title: const Text('下载管理'),
              description: const Text('查看和管理离线下载'),
              onPressed: (_) => _openPlaceholder(
                title: '下载管理',
                icon: Icons.download_rounded,
                owner: 'Member A',
              ),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.subtitles_rounded),
              title: const Text('弹幕设置'),
              description: const Text('弹幕数据源配置，播放时自动加载弹幕'),
              onPressed: (_) => Get.to(() => const DanmakuSettingsPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.cast_rounded),
              title: const Text('PC 连接'),
              description: const Text('连接 PC 后端，拉取推荐与视频源'),
              onPressed: (_) => Get.to(() => const ConnectionSettingsPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.video_library_rounded),
              title: const Text('PC 本地视频库 / 投屏控制'),
              description: const Text('手机播放电脑视频，或遥控 PC 浏览器播放'),
              onPressed: (_) => Get.toNamed(Routes.localVideos),
            ),
          ],
        ),

        // ── 应用与外观 ──
        SettingsSection(
          title: const Text('应用与外观'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.palette_rounded),
              title: const Text('外观设置'),
              description: const Text('深色模式、动态配色与配色方案'),
              onPressed: (_) => Get.to(() => const AppearanceSettingsPage()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.pages_rounded),
              title: const Text('界面设置'),
              description: const Text('设置应用界面样式'),
              onPressed: (_) =>
                  _openPlaceholder(title: '界面设置', icon: Icons.pages_rounded),
            ),
          ],
        ),

        // ── 其他 ──
        SettingsSection(
          title: const Text('其他'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.movie_outlined),
              title: const Text('旧版首页（Discovery）'),
              description: const Text('后端驱动的推荐首页'),
              onPressed: (_) => Get.to(
                () => const Scaffold(appBar: null, body: DiscoveryPage()),
              ),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('关于'),
              onPressed: (_) => _openPlaceholder(
                title: '关于',
                icon: Icons.info_outline_rounded,
                note: 'CineNest · AI 为你策展的私人影院入口',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 顶部用户画像卡槽位。
  ///
  /// 现在留空（返回零高占位），后续要加用户画像卡时，把卡片 Widget 返回
  /// 即可——它会作为列表的可滚动头部出现在所有分组之上。
  Widget _buildProfileHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.toNamed(Routes.tasteDna),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  child: const Icon(Icons.auto_awesome_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '口味 DNA',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '根据偏好、历史和收藏生成观影画像',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPlaceholder({
    required String title,
    required IconData icon,
    String? owner,
    String? note,
  }) {
    Get.to(
      () => PlaceholderSettingsPage(
        title: title,
        icon: icon,
        owner: owner,
        note: note ?? '该功能正在开发中，敬请期待。',
      ),
    );
  }
}
