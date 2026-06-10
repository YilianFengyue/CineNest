import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:cine_nest/pages/settings/color_type.dart';
import 'package:cine_nest/pages/settings/widgets/palette_card.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:cine_nest/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 外观设置子页（结构与功能照搬 Kazumi 的
/// `lib/pages/settings/theme_settings_page.dart`，用 `card_settings_ui`）。
///
/// 三项均为真实可用：
/// - **深色模式**：跟随系统 / 浅色 / 深色，沿用 Kazumi 的 [MenuAnchor] 下拉，
///   用 [Get.changeThemeMode] 即时生效。
/// - **动态配色**（Material You）：开启则取系统壁纸配色（Android 12+）。
/// - **配色方案**：关闭动态配色时，弹色卡对话框手动挑品牌种子色。
///
/// 后两者改的是 [Pref] 里的种子/开关，主题在 `MyApp.build` 据此计算，改完
/// 调 [Get.forceAppUpdate] 触发根组件重建即可即时生效。
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  final MenuController _menuController = MenuController();

  late ThemeMode _mode = Pref.themeMode;
  late bool _dynamic = Pref.dynamicColor;
  late Color _seed = Pref.seedColor;

  String _labelOf(ThemeMode m) => switch (m) {
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
    ThemeMode.system => '跟随系统',
  };

  IconData _iconOf(ThemeMode m) => switch (m) {
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };

  Future<void> _setMode(ThemeMode mode) async {
    await Pref.setThemeMode(mode);
    ThemeUtils.themeMode = mode;
    Get.changeThemeMode(mode);
    setState(() => _mode = mode);
  }

  Future<void> _setDynamic(bool value) async {
    await Pref.setDynamicColor(value);
    setState(() => _dynamic = value);
    Get.forceAppUpdate();
  }

  Future<void> _setSeed(Color color) async {
    await Pref.setSeedColor(color);
    setState(() => _seed = color);
    Get.forceAppUpdate();
  }

  void _pickSeed() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('配色方案'),
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final e in colorThemeTypes)
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _setSeed(e['color'] as Color);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PaletteCard(
                      color: e['color'] as Color,
                      selected:
                          (e['color'] as Color).toARGB32() == _seed.toARGB32(),
                    ),
                    Text(e['label'] as String),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外观设置')),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: const Text('外观'),
            tiles: [
              // 深色模式：照搬 Kazumi 的 MenuAnchor 下拉
              SettingsTile.navigation(
                leading: const Icon(Icons.brightness_6_rounded),
                title: const Text('深色模式'),
                onPressed: (_) {
                  _menuController.isOpen
                      ? _menuController.close()
                      : _menuController.open();
                },
                value: MenuAnchor(
                  consumeOutsideTap: true,
                  controller: _menuController,
                  builder: (_, __, ___) => Text(_labelOf(_mode)),
                  menuChildren: [
                    for (final m in ThemeMode.values)
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => _setMode(m),
                        leadingIcon: Icon(
                          _iconOf(m),
                          color: _mode == m
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        child: Text(
                          _labelOf(m),
                          style: TextStyle(
                            color: _mode == m
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 配色方案：动态配色开启时禁用
              SettingsTile.navigation(
                enabled: !_dynamic,
                leading: const Icon(Icons.palette_rounded),
                title: const Text('配色方案'),
                description: Text(_dynamic ? '关闭动态配色后可手动选择' : '当前种子色生成整套明暗主题'),
                value: _ColorDot(color: _dynamic ? null : _seed),
                onPressed: (_) => _pickSeed(),
              ),
              // 动态配色开关
              SettingsTile.switchTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('动态配色'),
                description: const Text('跟随系统壁纸取色（Android 12+）'),
                initialValue: _dynamic,
                onToggle: (v) => _setDynamic(v ?? !_dynamic),
              ),
            ],
            bottomInfo: const Text('动态配色仅支持 Android 12 及以上和桌面平台'),
          ),
        ],
      ),
    );
  }
}

/// 配色方案 tile 右侧的小色点。
class _ColorDot extends StatelessWidget {
  const _ColorDot({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant),
      ),
    );
  }
}
