import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../services/logger.dart';
import '../utils/storage_pref.dart';

abstract class DanmakuSource {
  bool get hasCredentials;
  Future<List<DanDanComment>> fetchDanmaku({
    required String title,
    int? tmdbId,
    int? episodeNumber,
  });
  Future<String> debugTest(String testKeyword);
}

class DanDanComment {
  const DanDanComment({
    required this.timeMs,
    required this.mode,
    required this.color,
    required this.content,
  });

  final int timeMs;

  /// 1=滚动, 4=底部, 5=顶部
  final int mode;

  final int color;

  final String content;
}

class DanDanPlayService implements DanmakuSource {
  DanDanPlayService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.dandanplay.net',
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  /// 签名模式认证：base64(sha256(AppId + Timestamp + Path + AppSecret))
  Map<String, String> _signHeaders(String apiPath) {
    final appId = Pref.dandanAppId;
    final appSecret = Pref.dandanAppSecret;
    if (appId.isEmpty || appSecret.isEmpty) return {};

    final timestamp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final data = '$appId$timestamp$apiPath$appSecret';
    final hash = sha256.convert(utf8.encode(data));
    final signature = base64.encode(hash.bytes);

    logger.d('[弹幕] 签名: path=$apiPath ts=$timestamp');
    return {
      'X-AppId': appId,
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }

  @override
  bool get hasCredentials =>
      Pref.dandanAppId.isNotEmpty && Pref.dandanAppSecret.isNotEmpty;

  Future<List<DanDanEpisode>> searchEpisodes({
    String? animeName,
    int? tmdbId,
    int? episode,
  }) async {
    if (!hasCredentials) {
      logger.w('[弹幕] searchEpisodes 跳过：未配置 AppId/AppSecret');
      return [];
    }
    final params = <String, dynamic>{};
    if (tmdbId != null) params['tmdbId'] = tmdbId;
    if (animeName != null && animeName.isNotEmpty) params['anime'] = animeName;
    if (episode != null) params['episode'] = episode;
    if (params.isEmpty) {
      logger.w('[弹幕] searchEpisodes 跳过：无搜索参数');
      return [];
    }

    logger.i('[弹幕] searchEpisodes 请求: $params');
    try {
      const path = '/api/v2/search/episodes';
      final resp = await _dio.get(
        path,
        queryParameters: params,
        options: Options(headers: _signHeaders(path)),
      );

      logger.d('[弹幕] searchEpisodes HTTP ${resp.statusCode}');
      final data = resp.data;
      if (data is! Map) {
        logger.w('[弹幕] searchEpisodes 响应不是 Map: ${data.runtimeType}');
        return [];
      }
      if (data['success'] != true) {
        logger.w('[弹幕] searchEpisodes API 返回失败: '
            'errorCode=${data['errorCode']}, errorMessage=${data['errorMessage']}');
        return [];
      }

      final animes = data['animes'] as List? ?? [];
      logger.i('[弹幕] searchEpisodes 匹配到 ${animes.length} 部番剧');
      final results = <DanDanEpisode>[];
      for (final anime in animes) {
        final episodes = anime['episodes'] as List? ?? [];
        final animeTitle = anime['animeTitle'] as String? ?? '';
        logger.d('[弹幕]   ├─ $animeTitle (${episodes.length} 集)');
        for (final ep in episodes) {
          results.add(DanDanEpisode(
            episodeId: ep['episodeId'] as int,
            animeTitle: animeTitle,
            episodeTitle: ep['episodeTitle'] as String? ?? '',
          ));
        }
      }
      logger.i('[弹幕] searchEpisodes 共 ${results.length} 集可选');
      return results;
    } on DioException catch (e) {
      logger.e('[弹幕] searchEpisodes 网络错误: '
          '${e.type} ${e.response?.statusCode} ${e.message}');
      return [];
    } catch (e) {
      logger.e('[弹幕] searchEpisodes 异常: $e');
      return [];
    }
  }

  Future<List<DanDanComment>> getComments(int episodeId) async {
    if (!hasCredentials) return [];
    logger.i('[弹幕] getComments episodeId=$episodeId');
    try {
      final path = '/api/v2/comment/$episodeId';
      final resp = await _dio.get(
        path,
        queryParameters: {'withRelated': true, 'chConvert': 1},
        options: Options(headers: _signHeaders(path)),
      );

      logger.d('[弹幕] getComments HTTP ${resp.statusCode}');
      final data = resp.data;
      if (data is! Map) return [];

      final count = data['count'] as int? ?? 0;
      final comments = data['comments'] as List? ?? [];
      logger.i('[弹幕] getComments 服务端报告 count=$count, 实际 ${comments.length} 条');

      return comments.map((c) {
        final p = (c['p'] as String? ?? '0,1,16777215').split(',');
        final timeSec = double.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0;
        final mode = int.tryParse(p.length > 1 ? p[1] : '1') ?? 1;
        final colorInt =
            int.tryParse(p.length > 2 ? p[2] : '16777215') ?? 16777215;
        return DanDanComment(
          timeMs: (timeSec * 1000).round(),
          mode: mode,
          color: 0xFF000000 | colorInt,
          content: c['m'] as String? ?? '',
        );
      }).toList();
    } on DioException catch (e) {
      logger.e('[弹幕] getComments 网络错误: '
          '${e.type} ${e.response?.statusCode} ${e.message}');
      return [];
    } catch (e) {
      logger.e('[弹幕] getComments 异常: $e');
      return [];
    }
  }

  @override
  Future<List<DanDanComment>> fetchDanmaku({
    required String title,
    int? tmdbId,
    int? episodeNumber,
  }) async {
    logger.i('[弹幕] ═══ fetchDanmaku 开始 ═══');
    logger.i('[弹幕] title="$title" tmdbId=$tmdbId episode=$episodeNumber');

    final episodes = await searchEpisodes(
      animeName: title,
      tmdbId: tmdbId,
      episode: episodeNumber,
    );
    if (episodes.isEmpty) {
      logger.w('[弹幕] 未匹配到任何番剧/集，弹幕为空');
      return [];
    }

    final eid = episodes.first.episodeId;
    logger.i('[弹幕] 选中: episodeId=$eid '
        '(${episodes.first.animeTitle} - ${episodes.first.episodeTitle})');

    final items = await getComments(eid);
    items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    if (items.isNotEmpty) {
      logger.i('[弹幕] ═══ 成功加载 ${items.length} 条弹幕 ═══');
      logger.d('[弹幕] 前3条: ${items.take(3).map((e) => '[${e.timeMs}ms] ${e.content}').join(' | ')}');
    } else {
      logger.w('[弹幕] ═══ episodeId=$eid 弹幕为空 ═══');
    }
    return items;
  }

  @override
  Future<String> debugTest(String testKeyword) async {
    final buf = StringBuffer();
    buf.writeln('── 弹弹Play API 调试 ──');
    buf.writeln('AppId: ${Pref.dandanAppId.isEmpty ? "❌ 未配置" : "✓ ${Pref.dandanAppId}"}');
    buf.writeln('AppSecret: ${Pref.dandanAppSecret.isEmpty ? "❌ 未配置" : "✓ (已配置, ${Pref.dandanAppSecret.length}字符)"}');

    if (!hasCredentials) {
      buf.writeln('\n⚠️ 缺少 API 凭证，无法测试');
      return buf.toString();
    }

    buf.writeln('\n搜索关键字: "$testKeyword"');
    try {
      const searchPath = '/api/v2/search/episodes';
      final resp = await _dio.get(
        searchPath,
        queryParameters: {'anime': testKeyword},
        options: Options(headers: _signHeaders(searchPath)),
      );
      buf.writeln('HTTP: ${resp.statusCode}');

      final data = resp.data;
      if (data is Map) {
        buf.writeln('success: ${data['success']}');
        if (data['success'] != true) {
          buf.writeln('errorCode: ${data['errorCode']}');
          buf.writeln('errorMessage: ${data['errorMessage']}');
        } else {
          final animes = data['animes'] as List? ?? [];
          buf.writeln('匹配番剧数: ${animes.length}');
          for (final anime in animes.take(5)) {
            final title = anime['animeTitle'] ?? '?';
            final eps = (anime['episodes'] as List?)?.length ?? 0;
            buf.writeln('  ├─ $title ($eps 集)');
            final episodes = anime['episodes'] as List? ?? [];
            for (final ep in episodes.take(3)) {
              buf.writeln('  │  └─ [${ep['episodeId']}] ${ep['episodeTitle']}');
            }
          }

          // 尝试拉第一集弹幕
          if (animes.isNotEmpty) {
            final firstEps = animes.first['episodes'] as List?;
            if (firstEps != null && firstEps.isNotEmpty) {
              final eid = firstEps.first['episodeId'] as int;
              buf.writeln('\n拉取弹幕: episodeId=$eid');
              final commentPath = '/api/v2/comment/$eid';
              final commentResp = await _dio.get(
                commentPath,
                queryParameters: {'withRelated': true, 'chConvert': 1},
                options: Options(headers: _signHeaders(commentPath)),
              );
              final cData = commentResp.data;
              if (cData is Map) {
                final count = cData['count'] ?? 0;
                final comments = cData['comments'] as List? ?? [];
                buf.writeln('弹幕数: $count (实际 ${comments.length})');
                for (final c in comments.take(5)) {
                  buf.writeln('  ${c['p']} | ${c['m']}');
                }
              }
            }
          }
        }
      } else {
        buf.writeln('响应类型异常: ${data.runtimeType}');
      }
    } on DioException catch (e) {
      buf.writeln('❌ 网络错误: ${e.type}');
      buf.writeln('状态码: ${e.response?.statusCode}');
      buf.writeln('消息: ${e.message}');
      if (e.response?.data != null) {
        buf.writeln('响应: ${e.response?.data}');
      }
    } catch (e) {
      buf.writeln('❌ 异常: $e');
    }

    return buf.toString();
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
