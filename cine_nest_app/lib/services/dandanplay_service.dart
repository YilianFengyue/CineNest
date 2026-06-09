import 'package:dio/dio.dart';

import '../services/logger.dart';
import '../utils/storage_pref.dart';

class DanDanComment {
  const DanDanComment({
    required this.timeMs,
    required this.mode,
    required this.color,
    required this.content,
  });

  /// 弹幕出现时间（毫秒）
  final int timeMs;

  /// 1=滚动, 4=底部, 5=顶部
  final int mode;

  /// 颜色 ARGB int
  final int color;

  final String content;
}

class DanDanPlayService {
  DanDanPlayService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.dandanplay.net',
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  Map<String, String> get _authHeaders {
    final appId = Pref.dandanAppId;
    final appSecret = Pref.dandanAppSecret;
    if (appId.isEmpty || appSecret.isEmpty) return {};
    return {'X-AppId': appId, 'X-AppSecret': appSecret};
  }

  bool get hasCredentials =>
      Pref.dandanAppId.isNotEmpty && Pref.dandanAppSecret.isNotEmpty;

  /// 用片名搜番剧，返回 episodeId 列表。
  /// 优先 tmdbId 精确匹配，fallback 到 anime 关键字搜索。
  Future<List<DanDanEpisode>> searchEpisodes({
    String? animeName,
    int? tmdbId,
    int? episode,
  }) async {
    if (!hasCredentials) return [];
    try {
      final params = <String, dynamic>{};
      if (tmdbId != null) {
        params['tmdbId'] = tmdbId;
      }
      if (animeName != null && animeName.isNotEmpty) {
        params['anime'] = animeName;
      }
      if (episode != null) {
        params['episode'] = episode;
      }
      if (params.isEmpty) return [];

      final resp = await _dio.get(
        '/api/v2/search/episodes',
        queryParameters: params,
        options: Options(headers: _authHeaders),
      );

      final data = resp.data;
      if (data is! Map || data['success'] != true) return [];

      final animes = data['animes'] as List? ?? [];
      final results = <DanDanEpisode>[];
      for (final anime in animes) {
        final episodes = anime['episodes'] as List? ?? [];
        final animeTitle = anime['animeTitle'] as String? ?? '';
        for (final ep in episodes) {
          results.add(DanDanEpisode(
            episodeId: ep['episodeId'] as int,
            animeTitle: animeTitle,
            episodeTitle: ep['episodeTitle'] as String? ?? '',
          ));
        }
      }
      return results;
    } catch (e) {
      logger.w('dandanplay search failed: $e');
      return [];
    }
  }

  /// 拉取某集的全部弹幕（含第三方关联弹幕）。
  Future<List<DanDanComment>> getComments(int episodeId) async {
    if (!hasCredentials) return [];
    try {
      final resp = await _dio.get(
        '/api/v2/comment/$episodeId',
        queryParameters: {'withRelated': true, 'chConvert': 1},
        options: Options(headers: _authHeaders),
      );

      final data = resp.data;
      if (data is! Map) return [];

      final comments = data['comments'] as List? ?? [];
      return comments.map((c) {
        final p = (c['p'] as String? ?? '0,1,16777215').split(',');
        final timeSec = double.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0;
        final mode = int.tryParse(p.length > 1 ? p[1] : '1') ?? 1;
        final colorInt = int.tryParse(p.length > 2 ? p[2] : '16777215') ??
            16777215;
        return DanDanComment(
          timeMs: (timeSec * 1000).round(),
          mode: mode,
          color: 0xFF000000 | colorInt,
          content: c['m'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      logger.w('dandanplay getComments failed: $e');
      return [];
    }
  }

  /// 一步到位：搜索+拉弹幕。
  /// 返回按时间排序的弹幕列表。
  Future<List<DanDanComment>> fetchDanmaku({
    required String title,
    int? tmdbId,
    int? episodeNumber,
  }) async {
    final episodes = await searchEpisodes(
      animeName: title,
      tmdbId: tmdbId,
      episode: episodeNumber,
    );
    if (episodes.isEmpty) return [];

    final eid = episodes.first.episodeId;
    logger.i('dandanplay matched episodeId=$eid '
        '(${episodes.first.animeTitle} - ${episodes.first.episodeTitle})');

    final items = await getComments(eid);
    items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    logger.i('dandanplay fetched ${items.length} danmaku');
    return items;
  }
}

class DanDanEpisode {
  const DanDanEpisode({
    required this.episodeId,
    required this.animeTitle,
    required this.episodeTitle,
  });

  final int episodeId;
  final String animeTitle;
  final String episodeTitle;
}
