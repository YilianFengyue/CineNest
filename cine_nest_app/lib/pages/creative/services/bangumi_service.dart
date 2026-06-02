import 'package:cine_nest/pages/creative/models/bangumi_subject.dart';
import 'package:dio/dio.dart';

/// Bangumi（番组计划）数据服务 —— 独立 Dio 直连公开 API，不经 PC 后端。
///
/// 用途：成员 C 自测阶段，用真实番剧/影视海报+评分填充资讯/海报卡，不依赖队友后端。
/// 公开只读接口，无需 token、无需签名，仅要求带 User-Agent（bgm.tv 礼貌规范）。
///
/// 长期联调时，电影元数据应走成员 B 的 TMDB（`/api/movie`），此服务作为
/// 临时数据源 / 番剧方向的补充。
class BangumiService {
  BangumiService._();
  static final BangumiService instance = BangumiService._();

  static const String _apiDomain = 'https://api.bgm.tv';

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        // bgm.tv 要求标识来源，否则可能被限流
        'User-Agent': 'CineNest/1.0 (https://github.com/cinenest/cinenest)',
      },
    ),
  );

  /// 热门条目（按评分排序）。type: 2=动画 / 6=三次元影视。
  ///
  /// 用 v0 search（空关键词 + rank 排序）实现，只依赖主域名 api.bgm.tv。
  /// 不用 next.bgm.tv 的 /p1/trending —— 那个新域名在部分设备/网络连不上。
  /// 好处：v0 search 返回的条目自带 summary 真实简介。
  Future<List<BangumiSubject>> trending({int type = 2, int limit = 12}) async {
    final res = await _dio.post(
      '$_apiDomain/v0/search/subjects',
      queryParameters: {'limit': limit, 'offset': 0},
      data: {
        'keyword': '',
        'sort': 'rank',
        'filter': {
          'type': [type],
          'rank': ['>0', '<=99999'],
        },
      },
    );
    final list = (res.data['data'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => BangumiSubject.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 关键词搜索条目（POST）。
  Future<List<BangumiSubject>> search(String keyword, {int limit = 12}) async {
    final res = await _dio.post(
      '$_apiDomain/v0/search/subjects',
      queryParameters: {'limit': limit, 'offset': 0},
      data: {
        'keyword': keyword,
        'sort': 'rank',
      },
    );
    final list = (res.data['data'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => BangumiSubject.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 条目详情（含 summary，用于 F8 海报展开）。
  Future<BangumiSubject> subject(int id) async {
    final res = await _dio.get('$_apiDomain/v0/subjects/$id');
    return BangumiSubject.fromJson((res.data as Map).cast<String, dynamic>());
  }
}
