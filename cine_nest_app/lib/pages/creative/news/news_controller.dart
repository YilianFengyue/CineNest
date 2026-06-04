import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/news/news_mock.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

/// 一条资讯 = 一串可渲染 blocks（newsCard + 可选 mediaGallery）。
class NewsEntry {
  final String id;
  final String title;
  final List<ContentBlock> blocks;
  const NewsEntry({required this.id, required this.title, required this.blocks});

  /// 取首张可用封面（newsCard.cover 或 mediaGallery 首图），收藏元信息用。
  String get cover {
    for (final b in blocks) {
      final c = b.str('cover');
      if (c.isNotEmpty) return c;
      final urls = b.strList('urls');
      if (urls.isNotEmpty) return urls.first;
    }
    return '';
  }
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

  /// 当前展示的是否为 mock 兜底数据（后端拉不到时）。
  final RxBool usingMock = false.obs;

  /// 「只看收藏」筛选开关。
  final RxBool favOnly = false.obs;

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
        final parsed = _parse((res.data as Map)['items']);
        if (parsed.isNotEmpty) {
          items.value = parsed;
          usingMock.value = false;
        } else {
          _fallbackToMock();
        }
      } else {
        _fallbackToMock();
      }
    } catch (e, st) {
      logger.e('资讯加载失败，回退 mock', error: e, stackTrace: st);
      _fallbackToMock();
    }
    loading.value = false;
  }

  /// 后端拉不到 / 返回空 → 用 mock 兜底，保证列表永远有内容可调。
  void _fallbackToMock() {
    items.value = mockNewsEntries();
    usingMock.value = true;
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
