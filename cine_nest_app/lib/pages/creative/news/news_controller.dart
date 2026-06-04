import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

/// 一条资讯 = 一串可渲染 blocks（newsCard + 可选 mediaGallery）。
class NewsEntry {
  final String id;
  final String title;
  final List<ContentBlock> blocks;
  const NewsEntry({required this.id, required this.title, required this.blocks});
}

/// 资讯 Tab 控制器（F12）。
///
/// 数据走后端 `/api/news`（`microdesign.v1.1`，由 Catalog 热门 + 可选 AI 生成）。
/// 每条 item 的 `blocks` 直接交给 `BlockRenderer` 渲染，newsCard 自带点击跳海报。
/// 失败保留上次结果或空态提示，不崩。
class NewsController extends GetxController {
  static NewsController get to => Get.find<NewsController>();

  final RxBool loading = true.obs;
  final RxString error = ''.obs;
  final RxList<NewsEntry> items = <NewsEntry>[].obs;

  /// 「新建资讯」生成中标记（避免重复触发）。
  final RxBool generating = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshNews();
  }

  Future<void> refreshNews({bool refresh = false}) async {
    if (items.isEmpty) loading.value = true;
    error.value = '';
    try {
      final res = await Request().get(
        ApiConstants.news,
        queryParameters: {'limit': 20, 'refresh': refresh},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final raw = (res.data as Map)['items'];
        items.value = _parse(raw);
        if (items.isEmpty) error.value = '暂无资讯';
      } else {
        if (items.isEmpty) error.value = '资讯加载失败';
      }
    } catch (e, st) {
      logger.e('资讯加载失败', error: e, stackTrace: st);
      if (items.isEmpty) error.value = '连接后端失败，请检查设置中的地址';
    }
    loading.value = false;
  }

  /// 让 AI 为某主题生成一条带海报图的资讯，成功后刷新列表置顶。
  Future<bool> generateNews(String query) async {
    final q = query.trim();
    if (q.isEmpty || generating.value) return false;
    generating.value = true;
    try {
      final res = await Request().post(
        ApiConstants.newsGenerate,
        data: {'query': q},
        // AI 生图较慢，单独放长收/发超时，避免被默认 10s 掐断。
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
      if (res.statusCode == 200) {
        await refreshNews(refresh: false);
        return true;
      }
      logger.w('资讯生成失败: HTTP ${res.statusCode} ${res.data}');
      return false;
    } catch (e, st) {
      logger.e('资讯生成异常', error: e, stackTrace: st);
      return false;
    } finally {
      generating.value = false;
    }
  }

  List<NewsEntry> _parse(dynamic raw) {
    if (raw is! List) return const [];
    final out = <NewsEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      out.add(
        NewsEntry(
          id: m['id'] as String? ?? '',
          title: m['title'] as String? ?? '',
          blocks: ContentBlock.listFrom(m['blocks']),
        ),
      );
    }
    return out;
  }
}
