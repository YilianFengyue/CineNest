import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/video_source.dart';

/// API wrapper for member A's video source endpoints.
class SourceApiService {
  const SourceApiService();

  /// Search playable sources by movie name.
  Future<List<VideoSource>> searchSources(String movieName) async {
    final fallback = fallbackSources(movieName);
    final response = await Request().get(
      ApiConstants.sourcesSearch,
      queryParameters: {'movie_name': movieName},
    );
    return _mergeSources(_parseSourceList(response.data), fallback);
  }

  /// Parse a source id into a playable URL.
  Future<VideoSource> parseSource(
    String sourceId, {
    int episodeIndex = 0,
  }) async {
    final local = parseLocalSource(sourceId);
    if (local != null) {
      return local;
    }

    final response = await Request().get(
      ApiConstants.sourcesParse,
      queryParameters: {'source_id': sourceId, 'episode_index': episodeIndex},
    );
    if (response.data is Map) {
      return VideoSource.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw Exception('Invalid source parse response.');
  }

  /// Search Bilibili videos by keyword, usually "movie name + 解说".
  Future<List<VideoSource>> searchBilibili(String keyword) async {
    final fallback = fallbackBilibili(keyword);
    final response = await Request().get(
      ApiConstants.bilibiliSearch,
      queryParameters: {'keyword': keyword},
    );
    final parsed = _parseSourceList(response.data);
    return parsed.isEmpty ? [fallback] : _mergeSources(parsed, [fallback]);
  }

  List<VideoSource> fallbackSources(String movieName) {
    final keyword = movieName.trim().isEmpty ? 'demo' : movieName.trim();
    return [
      VideoSource(
        id: 'demo:${Uri.encodeComponent(keyword)}',
        name: 'TEST ONLY - fixed demo video for $keyword',
        quality: '720P fixed sample',
        type: SourceType.netdisk,
      ),
      fallbackBilibili('$keyword review'),
    ];
  }

  VideoSource fallbackBilibili(String keyword) {
    final searchKeyword = keyword.trim().isEmpty
        ? 'movie review'
        : keyword.trim();
    final encoded = Uri.encodeComponent(searchKeyword);
    return VideoSource(
      id: 'bili:$encoded',
      name: '$searchKeyword - Bilibili search',
      quality: 'WebView',
      type: SourceType.bilibili,
      playUrl: 'https://m.bilibili.com/search?keyword=$encoded',
      cover: 'https://www.bilibili.com/favicon.ico',
      playCount: 0,
    );
  }

  VideoSource? parseLocalSource(String sourceId) {
    final value = sourceId.trim();
    if (value.startsWith('demo:')) {
      final rawKeyword = value.substring('demo:'.length);
      final keyword = _safeDecode(rawKeyword);
      return VideoSource(
        id: value,
        name: 'TEST ONLY - fixed demo video for $keyword',
        quality: '720P fixed sample',
        type: SourceType.netdisk,
        playUrl: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
      );
    }

    if (value.startsWith('bili:')) {
      final rawKeyword = value.substring('bili:'.length);
      final keyword = _safeDecode(rawKeyword);
      if (keyword.toUpperCase().startsWith('BV')) {
        return null;
      }
      final encoded = Uri.encodeComponent(keyword);
      return VideoSource(
        id: value,
        name: '$keyword - Bilibili search',
        quality: 'WebView',
        type: SourceType.bilibili,
        playUrl: 'https://m.bilibili.com/search?keyword=$encoded',
      );
    }

    return null;
  }

  String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  List<VideoSource> _parseSourceList(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => VideoSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<VideoSource> _mergeSources(
    List<VideoSource> primary,
    List<VideoSource> fallback,
  ) {
    final merged = <VideoSource>[];
    final seen = <String>{};
    for (final source in [...primary, ...fallback]) {
      if (source.id.trim().isEmpty) {
        continue;
      }
      if (seen.add(source.id)) {
        merged.add(source);
      }
    }
    return merged;
  }
}
