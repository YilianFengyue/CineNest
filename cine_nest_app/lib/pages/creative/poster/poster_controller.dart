import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/poster/poster_mock.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// F8 互动海报控制器。
///
/// 解析后端 `PosterSpec`（mock 与真后端结构一致）：抽出头图/标题/评分/风格，
/// 其余区块交给 `BlockRenderer` 渲染。后端就绪后把 [loadMock] 换成 [fetchReal] 即可。
class PosterController extends GetxController {
  final RxBool loading = true.obs;
  final RxString errorMsg = ''.obs;

  // 头部
  String backdrop = '';
  String poster = '';
  String title = '';
  String subtitle = '';
  String style = 'warm';
  double? rating;
  String ratingLabel = '';

  /// 头图以下的正文区块（已剔除 banner）。
  final RxList<ContentBlock> body = <ContentBlock>[].obs;

  /// 底部主操作（立即播放）。
  MicroAction? primaryPlay;

  /// 入参：`{catalog_provider_id, catalog_source_id, media_kind}` 走真后端；否则 mock。
  late final Map<String, dynamic> _args;

  @override
  void onInit() {
    super.onInit();
    final raw = Get.arguments;
    _args = raw is Map ? raw.cast<String, dynamic>() : const {};
    _load();
  }

  Future<void> _load() async {
    loading.value = true;
    errorMsg.value = '';
    final provider = _args['catalog_provider_id'] as String?;
    final source = _args['catalog_source_id'] as String?;
    try {
      if (provider != null && source != null) {
        await _fetchReal(provider, source,
            (_args['media_kind'] as String?) ?? 'movie');
      } else {
        _applySpec(posterMockSpec());
      }
    } catch (e, st) {
      logger.e('海报加载失败', error: e, stackTrace: st);
      errorMsg.value = '海报加载失败，请稍后重试';
    }
    loading.value = false;
  }

  Future<void> _fetchReal(String provider, String source, String mediaKind) async {
    final res = await Request().get(
      ApiConstants.posterCatalog(provider, source),
      queryParameters: {'media_kind': mediaKind},
    );
    final data = res.data;
    if (data is Map) {
      _applySpec(data.cast<String, dynamic>());
    } else {
      errorMsg.value = '海报数据异常';
    }
  }

  /// 解析 PosterSpec → 头部字段 + 正文区块（mock / 真后端通用）。
  void _applySpec(Map<String, dynamic> spec) {
    final blocks = ContentBlock.listFrom(spec['blocks']);
    final banner = blocks.firstWhere(
      (b) => b.type == ContentBlockType.banner,
      orElse: () => const ContentBlock(ContentBlockType.unknown),
    );
    backdrop = banner.str('image');
    poster = banner.str('poster', backdrop);
    title = (spec['title'] as String?)?.trim().isNotEmpty == true
        ? spec['title'] as String
        : banner.str('title');
    subtitle = (spec['subtitle'] as String?)?.trim().isNotEmpty == true
        ? spec['subtitle'] as String
        : banner.str('subtitle');
    style = (spec['style'] as String?) ??
        banner.data['style'] as String? ??
        'warm';

    final ratingBlock = blocks.firstWhere(
      (b) => b.type == ContentBlockType.rating,
      orElse: () => const ContentBlock(ContentBlockType.unknown),
    );
    if (ratingBlock.type == ContentBlockType.rating) {
      rating = ratingBlock.number('score');
      ratingLabel = ratingBlock.str('label');
    }

    body.value =
        blocks.where((b) => b.type != ContentBlockType.banner).toList();

    final actions = (spec['actions'] as List?)
            ?.whereType<Map>()
            .map((e) => MicroAction.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [];
    primaryPlay = actions.cast<MicroAction?>().firstWhere(
          (a) => a?.type == 'resolveAndPlay',
          orElse: () => null,
        );
  }

  Future<void> reload() => _load();

  /// 收藏 key：优先用 catalog id（片维度，跨资讯/推荐/海报复用），否则退回标题。
  String get favKey {
    final p = _args['catalog_provider_id'] as String?;
    final s = _args['catalog_source_id'] as String?;
    if (p != null && p.isNotEmpty && s != null && s.isNotEmpty) {
      return 'poster:$p:$s';
    }
    return title.isNotEmpty ? 'poster:$title' : '';
  }

  /// 按 style 取强调色（驱动头部渐变 / 评分高亮），全部落在 colorScheme 内。
  Color accent(ColorScheme cs) {
    switch (style) {
      case 'neon':
        return cs.primary;
      case 'contrast':
        return cs.tertiary;
      case 'warm':
      default:
        return cs.secondary;
    }
  }
}
