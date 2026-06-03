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
      _setting.get(SettingBoxKey.enableHttp2, defaultValue: true);

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
  /// 当前选中的对话模型 id（前端展示用，后端待接 model 字段）。
  static String get chatModelId =>
      _setting.get(SettingBoxKey.chatModel, defaultValue: 'default');
  static Future<void> setChatModelId(String value) =>
      _setting.put(SettingBoxKey.chatModel, value);
}
