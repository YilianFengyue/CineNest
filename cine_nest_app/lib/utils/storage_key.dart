/// Hive 存储键常量（移植自 PiliPlus 的 `lib/utils/storage_key.dart`，裁剪为本项目所需）。
///
/// 约定：所有写入 setting / localCache 等 Box 的 key 都集中声明于此，避免散落硬编码。
abstract final class SettingBoxKey {
  // ── 网络 ──
  /// 后端基址（PC 的 http://IP:Port），F7 连接设置写入。
  static const String baseUrl = 'baseUrl';
  static const String pcHost = 'pcHost';
  static const String pcPort = 'pcPort';
  static const String enableHttp2 = 'enableHttp2';
  static const String retryCount = 'retryCount';
  static const String retryDelay = 'retryDelay';

  // ── 主题 / UI ──
  static const String themeMode = 'themeMode';
  static const String dynamicColor = 'dynamicColor';
  static const String seedColor = 'seedColor';
  static const String uiScale = 'uiScale';
}

/// 本地缓存键（非用户设置，运行期数据）。
abstract final class LocalCacheKey {
  /// 用户偏好（成员 B：喜欢/不喜欢的类型等），以 JSON Map 存储。
  static const String userPreference = 'userPreference';

  /// 观影历史（成员 B），以 List 存储。
  static const String watchHistory = 'watchHistory';
}
