import 'package:cine_nest/utils/storage.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

/// 创意模块收藏（资讯 / 海报通用），本地 Hive 持久化。
///
/// 以一个稳定 [id] 标识被收藏的对象（资讯条目 id、海报 catalog id 等），
/// 另存少量展示元信息（标题/封面/类型），方便后续做"我的收藏"页。
/// UI 直接 `Obx(() => ... FavoritesController.to.isFav(id) ...)` 响应式联动。
class FavoritesController extends GetxController {
  static FavoritesController get to => Get.isRegistered<FavoritesController>()
      ? Get.find<FavoritesController>()
      : Get.put(FavoritesController(), permanent: true);

  static const String _key = 'creativeFavorites';
  Box get _box => GStorage.localCache;

  /// 已收藏 id 集合（响应式）。
  final RxSet<String> ids = <String>{}.obs;

  /// id → { title, cover, type }，做收藏页时用。
  final Map<String, dynamic> _meta = {};

  @override
  void onInit() {
    super.onInit();
    final raw = _box.get(_key);
    if (raw is Map) {
      _meta
        ..clear()
        ..addAll(raw.cast<String, dynamic>());
      ids.assignAll(_meta.keys);
    }
  }

  bool isFav(String id) => ids.contains(id);

  /// 切换收藏态并落盘。
  Future<void> toggle(
    String id, {
    String title = '',
    String cover = '',
    String type = 'news',
  }) async {
    if (id.isEmpty) return;
    if (ids.contains(id)) {
      ids.remove(id);
      _meta.remove(id);
    } else {
      ids.add(id);
      _meta[id] = {'title': title, 'cover': cover, 'type': type};
    }
    await _box.put(_key, Map<String, dynamic>.from(_meta));
  }

  /// 收藏条目（含 id + 元信息），收藏页用。
  List<Map<String, dynamic>> entries() => _meta.entries.map((e) {
    final m = e.value is Map
        ? (e.value as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return {'id': e.key, ...m};
  }).toList();
}
