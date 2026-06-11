import 'package:dio/dio.dart';

import '../services/logger.dart';
import '../utils/storage_pref.dart';
import 'dandanplay_service.dart';

class LogvarDanmuService implements DanmakuSource {
  LogvarDanmuService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  String get _baseUrl {
    var url = Pref.logvarBaseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    final token = Pref.logvarToken.trim();
    if (token.isNotEmpty) return '$url/$token';
    return url;
  }

  @override
  bool get hasCredentials => Pref.logvarBaseUrl.trim().isNotEmpty;

  @override
  Future<List<DanDanComment>> fetchDanmaku({
    required String title,
    int? tmdbId,
    int? episodeNumber,
  }) async {
    logger.i('[弹幕/LogVar] ═══ fetchDanmaku 开始 ═══');
    logger.i('[弹幕/LogVar] title="$title" episode=$episodeNumber');

    int? episodeId = await _tryMatch(title, episodeNumber);
    episodeId ??= await _searchAndMatch(title, episodeNumber);

    if (episodeId == null) {
      logger.w('[弹幕/LogVar] 未匹配到任何作品，弹幕为空');
      return [];
    }

    logger.i('[弹幕/LogVar] 选中 episodeId=$episodeId');
    return _getComments(episodeId);
  }

  Future<int?> _tryMatch(String title, int? episodeNumber) async {
    try {
      final fileName = episodeNumber != null
          ? '$title S01E${episodeNumber.toString().padLeft(2, '0')}'
          : title;

      logger.d('[弹幕/LogVar] match: fileName="$fileName"');
      final resp = await _dio.post(
        '$_baseUrl/api/v2/match',
        data: {'fileName': fileName},
      );

      final data = resp.data;
      if (data is Map && data['isMatched'] == true) {
        final matches = data['matches'] as List? ?? [];
        if (matches.isNotEmpty) {
          final eid = matches.first['episodeId'] as int?;
          if (eid != null) {
            logger.i('[弹幕/LogVar] match 命中: episodeId=$eid '
                '(${matches.first['animeTitle']} - ${matches.first['episodeTitle']})');
            return eid;
          }
        }
      }
      logger.d('[弹幕/LogVar] match 未命中，走 search fallback');
    } on DioException catch (e) {
      logger.d('[弹幕/LogVar] match 网络错误: ${e.type} ${e.response?.statusCode}');
    } catch (e) {
      logger.d('[弹幕/LogVar] match 异常: $e');
    }
    return null;
  }

  Future<int?> _searchAndMatch(String title, int? episodeNumber) async {
    try {
      final searchResp = await _dio.get(
        '$_baseUrl/api/v2/search/anime',
        queryParameters: {'keyword': title},
      );

      final searchData = searchResp.data;
      if (searchData is! Map || searchData['success'] != true) return null;

      final animes = searchData['animes'] as List? ?? [];
      if (animes.isEmpty) return null;

      final animeId = animes.first['animeId'] as int?;
      if (animeId == null) return null;

      logger.i('[弹幕/LogVar] search 匹配到: '
          '${animes.first['animeTitle']} (animeId=$animeId)');

      final bangumiResp = await _dio.get('$_baseUrl/api/v2/bangumi/$animeId');
      final bangumiData = bangumiResp.data;
      if (bangumiData is! Map || bangumiData['success'] != true) return null;

      final bangumi = bangumiData['bangumi'] as Map?;
      if (bangumi == null) return null;

      final episodes = bangumi['episodes'] as List? ?? [];
      if (episodes.isEmpty) return null;

      if (episodeNumber != null) {
        for (final ep in episodes) {
          final epNum = ep['episodeNumber'];
          if (epNum != null && epNum.toString() == episodeNumber.toString()) {
            return ep['episodeId'] as int?;
          }
        }
      }

      return episodes.first['episodeId'] as int?;
    } on DioException catch (e) {
      logger.e('[弹幕/LogVar] search 网络错误: '
          '${e.type} ${e.response?.statusCode} ${e.message}');
      return null;
    } catch (e) {
      logger.e('[弹幕/LogVar] search 异常: $e');
      return null;
    }
  }

  Future<List<DanDanComment>> _getComments(int episodeId) async {
    try {
      final resp = await _dio.get(
        '$_baseUrl/api/v2/comment/$episodeId',
        queryParameters: {'format': 'json', 'duration': 'true'},
      );

      final data = resp.data;
      if (data is! Map) return [];

      final comments = data['comments'] as List? ?? [];
      final count = data['count'] as int? ?? comments.length;
      logger.i('[弹幕/LogVar] 弹幕 count=$count, 实际 ${comments.length} 条');

      final items = comments.map((c) {
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

      items.sort((a, b) => a.timeMs.compareTo(b.timeMs));

      if (items.isNotEmpty) {
        logger.i('[弹幕/LogVar] ═══ 成功加载 ${items.length} 条弹幕 ═══');
      }
      return items;
    } on DioException catch (e) {
      logger.e('[弹幕/LogVar] getComments 网络错误: '
          '${e.type} ${e.response?.statusCode} ${e.message}');
      return [];
    } catch (e) {
      logger.e('[弹幕/LogVar] getComments 异常: $e');
      return [];
    }
  }

  @override
  Future<String> debugTest(String testKeyword) async {
    final buf = StringBuffer();
    buf.writeln('── LogVar 弹幕 API 调试 ──');
    buf.writeln('Base URL: ${Pref.logvarBaseUrl.isEmpty ? "❌ 未配置" : "✓ ${Pref.logvarBaseUrl}"}');
    buf.writeln('Token: ${Pref.logvarToken.isEmpty ? "(未设置，公开访问)" : "✓ (已配置)"}');
    buf.writeln('完整地址: $_baseUrl');

    if (!hasCredentials) {
      buf.writeln('\n⚠️ 缺少 Base URL，无法测试');
      return buf.toString();
    }

    buf.writeln('\n── 检查服务状态 ──');
    try {
      final configResp = await _dio.get('$_baseUrl/api/config');
      final config = configResp.data;
      if (config is Map) {
        buf.writeln('版本: ${config['version'] ?? '?'}');
        buf.writeln('状态: ✓ 服务正常');
        final envs = config['envs'] as Map?;
        if (envs != null) {
          final sourceOrder = envs['SOURCE_ORDER'];
          if (sourceOrder != null) buf.writeln('源顺序: $sourceOrder');
        }
      }
    } on DioException catch (e) {
      buf.writeln('❌ 连接失败: ${e.type} ${e.response?.statusCode}');
      buf.writeln('   ${e.message}');
      return buf.toString();
    } catch (e) {
      buf.writeln('❌ 连接异常: $e');
      return buf.toString();
    }

    buf.writeln('\n── 搜索: "$testKeyword" ──');
    try {
      final searchResp = await _dio.get(
        '$_baseUrl/api/v2/search/anime',
        queryParameters: {'keyword': testKeyword},
      );
      final data = searchResp.data;
      if (data is Map && data['success'] == true) {
        final animes = data['animes'] as List? ?? [];
        buf.writeln('匹配作品数: ${animes.length}');
        for (final anime in animes.take(5)) {
          final title = anime['animeTitle'] ?? '?';
          final source = anime['source'] ?? '?';
          final epCount = anime['episodeCount'] ?? 0;
          buf.writeln('  ├─ $title (来源: $source, $epCount 集)');
        }

        if (animes.isNotEmpty) {
          final animeId = animes.first['animeId'];
          buf.writeln('\n── 详情: animeId=$animeId ──');
          final bangumiResp =
              await _dio.get('$_baseUrl/api/v2/bangumi/$animeId');
          final bData = bangumiResp.data;
          if (bData is Map && bData['success'] == true) {
            final bangumi = bData['bangumi'] as Map?;
            if (bangumi != null) {
              final episodes = bangumi['episodes'] as List? ?? [];
              buf.writeln('分集数: ${episodes.length}');
              for (final ep in episodes.take(3)) {
                buf.writeln(
                    '  └─ [${ep['episodeId']}] ${ep['episodeTitle']}');
              }

              if (episodes.isNotEmpty) {
                final eid = episodes.first['episodeId'];
                buf.writeln('\n── 弹幕: episodeId=$eid ──');
                final commentResp = await _dio.get(
                  '$_baseUrl/api/v2/comment/$eid',
                  queryParameters: {'format': 'json', 'duration': 'true'},
                );
                final cData = commentResp.data;
                if (cData is Map) {
                  final count = cData['count'] ?? 0;
                  final duration = cData['videoDuration'] ?? 0;
                  final comments = cData['comments'] as List? ?? [];
                  buf.writeln('弹幕数: $count (实际 ${comments.length})');
                  if (duration is int && duration > 0) {
                    buf.writeln('视频时长: ${duration}s');
                  }
                  for (final c in comments.take(5)) {
                    buf.writeln('  ${c['p']} | ${c['m']}');
                  }
                }
              }
            }
          }
        }
      } else {
        buf.writeln('搜索失败: ${data?['errorMessage'] ?? '未知错误'}');
      }
    } on DioException catch (e) {
      buf.writeln('❌ 搜索网络错误: ${e.type} ${e.response?.statusCode}');
    } catch (e) {
      buf.writeln('❌ 搜索异常: $e');
    }

    return buf.toString();
  }
}
