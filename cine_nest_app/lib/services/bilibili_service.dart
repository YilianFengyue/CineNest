import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/logger.dart';

class BiliVideo {
  const BiliVideo({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.author,
    required this.play,
    required this.danmaku,
    required this.duration,
    required this.durationSeconds,
    required this.pubdate,
    required this.appUrl,
    required this.fallbackUrl,
  });

  final String bvid;
  final String title;
  final String cover;
  final String author;
  final int play;
  final int danmaku;
  final String duration;
  final int durationSeconds;
  final String pubdate;
  final String appUrl;
  final String fallbackUrl;

  factory BiliVideo.fromJson(Map<String, dynamic> json) {
    final c = json['_cinenest'] as Map<String, dynamic>? ?? {};
    return BiliVideo(
      bvid: json['bvid'] as String? ?? '',
      title: c['title_plain'] as String? ?? json['title'] as String? ?? '',
      cover: c['cover_url'] as String? ?? '',
      author: json['author'] as String? ?? '',
      play: json['play'] as int? ?? 0,
      danmaku: json['danmaku'] as int? ?? json['video_review'] as int? ?? 0,
      duration: json['duration'] as String? ?? '',
      durationSeconds: c['duration_seconds'] as int? ?? 0,
      pubdate: c['pubdate_text'] as String? ?? '',
      appUrl: c['app_url'] as String? ?? '',
      fallbackUrl: c['fallback_url'] as String? ?? '',
    );
  }
}

class BiliVideoPage {
  const BiliVideoPage({
    required this.videos,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<BiliVideo> videos;
  final int page;
  final int pageSize;
  final bool hasMore;
}

class BilibiliService {
  const BilibiliService._();

  static Future<BiliVideoPage> getMovieVideos({
    required String movie,
    String? year,
    int page = 1,
    int pageSize = 12,
  }) async {
    try {
      final resp = await Request().get(
        ApiConstants.biliMovieVideos,
        queryParameters: {
          'movie': movie,
          if (year != null && year.isNotEmpty) 'year': year,
          'page': page,
          'page_size': pageSize,
        },
      );

      final data = resp.data;
      if (data is! Map<String, dynamic>) {
        return BiliVideoPage(
            videos: [], page: page, pageSize: pageSize, hasMore: false);
      }

      final items = data['data'] as List? ?? [];
      final extra = data['extra'] as Map<String, dynamic>? ?? {};
      final hasMore = extra['has_more'] as bool? ?? items.length >= pageSize;

      final videos = items
          .whereType<Map<String, dynamic>>()
          .map(BiliVideo.fromJson)
          .toList();

      logger.i('[B站] movie="$movie" page=$page 返回 ${videos.length} 条视频');
      return BiliVideoPage(
        videos: videos,
        page: page,
        pageSize: pageSize,
        hasMore: hasMore,
      );
    } catch (e) {
      logger.w('[B站] getMovieVideos 失败: $e');
      return BiliVideoPage(
          videos: [], page: page, pageSize: pageSize, hasMore: false);
    }
  }
}
