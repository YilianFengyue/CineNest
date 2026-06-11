import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/utils/storage.dart';
import 'package:cine_nest/utils/storage_key.dart';
import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:hive_ce/hive.dart';

/// 偏好读写门面（移植自 PiliPlus 的 `lib/utils/storage_pref.dart`）。
///
/// 所有对 [GStorage] 的强类型读写都收敛到这里，业务代码不直接碰 Box。
abstract final class Pref {
  static Box get _setting => GStorage.setting;

  // ───────────────────────── 网络 ─────────────────────────
  /// 后端基址。默认本机调试地址，运行期由 F7 连接设置覆盖。
  static String get baseUrl =>
      _setting.get(SettingBoxKey.baseUrl, defaultValue: ApiConstants.defaultBaseUrl);
  static Future<void> setBaseUrl(String value) =>
      _setting.put(SettingBoxKey.baseUrl, value);

  static String get pcHost =>
      _setting.get(SettingBoxKey.pcHost, defaultValue: '192.168.1.100');
  static Future<void> setPcHost(String value) =>
      _setting.put(SettingBoxKey.pcHost, value);

  static int get pcPort =>
      _setting.get(SettingBoxKey.pcPort, defaultValue: 8000);
  static Future<void> setPcPort(int value) =>
      _setting.put(SettingBoxKey.pcPort, value);

  static bool get enableHttp2 =>
      _setting.get(SettingBoxKey.enableHttp2, defaultValue: false);

  static int get retryCount =>
      _setting.get(SettingBoxKey.retryCount, defaultValue: 3);

  static int get retryDelay =>
      _setting.get(SettingBoxKey.retryDelay, defaultValue: 300);

  // ───────────────────────── 主题 / UI ─────────────────────────
  static ThemeMode get themeMode => ThemeMode.values[_setting.get(
    SettingBoxKey.themeMode,
    defaultValue: ThemeMode.system.index,
  )];
  static Future<void> setThemeMode(ThemeMode value) =>
      _setting.put(SettingBoxKey.themeMode, value.index);

  static bool get dynamicColor =>
      _setting.get(SettingBoxKey.dynamicColor, defaultValue: true);
  static Future<void> setDynamicColor(bool value) =>
      _setting.put(SettingBoxKey.dynamicColor, value);

  /// 品牌种子色（ARGB int）。默认影院蓝紫。
  static Color get seedColor => Color(
    _setting.get(SettingBoxKey.seedColor, defaultValue: 0xFF6B4EFF),
  );
  static Future<void> setSeedColor(Color value) =>
      _setting.put(SettingBoxKey.seedColor, value.toARGB32());

  static double get uiScale =>
      _setting.get(SettingBoxKey.uiScale, defaultValue: 1.0);

  // ───────────────────────── 对话（成员 C · F9）─────────────────────────
  /// 当前选中的对话模型 id（后端映射到具体模型）。
  static String get chatModelId =>
      _setting.get(SettingBoxKey.chatModel, defaultValue: 'default');
  static Future<void> setChatModelId(String value) =>
      _setting.put(SettingBoxKey.chatModel, value);

  // ───────────────────────── 弹幕 ─────────────────────────
  static String get danmakuSource =>
      _setting.get(SettingBoxKey.danmakuSource, defaultValue: 'logvar');
  static Future<void> setDanmakuSource(String v) =>
      _setting.put(SettingBoxKey.danmakuSource, v);

  static String get logvarBaseUrl =>
      _setting.get(SettingBoxKey.logvarBaseUrl, defaultValue: '');
  static Future<void> setLogvarBaseUrl(String v) =>
      _setting.put(SettingBoxKey.logvarBaseUrl, v);

  static String get logvarToken =>
      _setting.get(SettingBoxKey.logvarToken, defaultValue: '');
  static Future<void> setLogvarToken(String v) =>
      _setting.put(SettingBoxKey.logvarToken, v);

  static bool get hasDanmakuCredentials {
    if (danmakuSource == 'dandanplay') {
      return dandanAppId.isNotEmpty && dandanAppSecret.isNotEmpty;
    }
    return logvarBaseUrl.isNotEmpty;
  }

  static String get dandanAppId =>
      _setting.get(SettingBoxKey.dandanAppId, defaultValue: '');
  static Future<void> setDandanAppId(String v) =>
      _setting.put(SettingBoxKey.dandanAppId, v);

  static String get dandanAppSecret =>
      _setting.get(SettingBoxKey.dandanAppSecret, defaultValue: '');
  static Future<void> setDandanAppSecret(String v) =>
      _setting.put(SettingBoxKey.dandanAppSecret, v);

  static bool get danmakuEnabled =>
      _setting.get(SettingBoxKey.danmakuEnabled, defaultValue: true);
  static Future<void> setDanmakuEnabled(bool v) =>
      _setting.put(SettingBoxKey.danmakuEnabled, v);

  static double get danmakuOpacity =>
      _setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
  static Future<void> setDanmakuOpacity(double v) =>
      _setting.put(SettingBoxKey.danmakuOpacity, v);

  static double get danmakuFontScale =>
      _setting.get(SettingBoxKey.danmakuFontScale, defaultValue: 1.0);
  static Future<void> setDanmakuFontScale(double v) =>
      _setting.put(SettingBoxKey.danmakuFontScale, v);

  static double get danmakuArea =>
      _setting.get(SettingBoxKey.danmakuArea, defaultValue: 0.8);
  static Future<void> setDanmakuArea(double v) =>
      _setting.put(SettingBoxKey.danmakuArea, v);

  /// 滚动弹幕滑过屏幕的秒数（越大越慢）
  static double get danmakuDuration =>
      _setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
  static Future<void> setDanmakuDuration(double v) =>
      _setting.put(SettingBoxKey.danmakuDuration, v);

  static bool get danmakuHideScroll =>
      _setting.get(SettingBoxKey.danmakuHideScroll, defaultValue: false);
  static Future<void> setDanmakuHideScroll(bool v) =>
      _setting.put(SettingBoxKey.danmakuHideScroll, v);

  static bool get danmakuHideTop =>
      _setting.get(SettingBoxKey.danmakuHideTop, defaultValue: false);
  static Future<void> setDanmakuHideTop(bool v) =>
      _setting.put(SettingBoxKey.danmakuHideTop, v);

  static bool get danmakuHideBottom =>
      _setting.get(SettingBoxKey.danmakuHideBottom, defaultValue: false);
  static Future<void> setDanmakuHideBottom(bool v) =>
      _setting.put(SettingBoxKey.danmakuHideBottom, v);

  static bool get danmakuMassive =>
      _setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
  static Future<void> setDanmakuMassive(bool v) =>
      _setting.put(SettingBoxKey.danmakuMassive, v);

  static double get danmakuDensity =>
      _setting.get(SettingBoxKey.danmakuDensity, defaultValue: 1.0);
  static Future<void> setDanmakuDensity(double v) =>
      _setting.put(SettingBoxKey.danmakuDensity, v);

  static bool get danmakuHideColor =>
      _setting.get(SettingBoxKey.danmakuHideColor, defaultValue: false);
  static Future<void> setDanmakuHideColor(bool v) =>
      _setting.put(SettingBoxKey.danmakuHideColor, v);

  static bool get danmakuHideAdvanced =>
      _setting.get(SettingBoxKey.danmakuHideAdvanced, defaultValue: false);
  static Future<void> setDanmakuHideAdvanced(bool v) =>
      _setting.put(SettingBoxKey.danmakuHideAdvanced, v);
}
