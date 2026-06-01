import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 全局本地存储（移植自 PiliPlus 的 `lib/utils/storage.dart`）。
///
/// 母版用了多个带 TypeAdapter 的强类型 Box（UserInfoData/Account/CookieJar 等，
/// 均为 B站账号体系）。本项目剔除这些业务模型，只保留两个通用 dynamic Box：
///   · [setting]    —— 应用设置（主题、网络、PC 地址……）
///   · [localCache] —— 运行期缓存（用户偏好、观影历史、帖子缓存……）
///
/// 由于不再依赖自定义 TypeAdapter，无需 build_runner；复杂对象统一以 JSON Map 存取。
abstract final class GStorage {
  static late final Box<dynamic> setting;
  static late final Box<dynamic> localCache;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    Hive.init(path.join(dir.path, 'hive'));

    final results = await Future.wait([
      Hive.openBox('setting'),
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 4,
      ),
    ]);
    setting = results[0];
    localCache = results[1];
  }

  static Future<void> close() => Hive.close();

  static Future<void> clear() => Future.wait([
    setting.clear(),
    localCache.clear(),
  ]);
}
