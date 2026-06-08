import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/media_models.dart';
import '../models/source_config.dart';

class MoonTvDownstream {
  MoonTvDownstream({Dio? dio, this.timeout = const Duration(seconds: 6)})
    : _dio = dio ?? Dio();

  final Dio _dio;
  final Duration timeout;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'application/json,text/plain,*/*',
  };

  Future<List<AggregatorSearchResult>> searchFromApi(
    AggregatorSourceConfig source,
    String query, {
    int maxPages = 1,
  }) async {
    final first = await _searchPage(source, query, page: 1);
    if (maxPages <= 1) return first;

    final merged = [...first];
    final pageTasks = <Future<List<AggregatorSearchResult>>>[];
    for (var page = 2; page <= maxPages; page++) {
      pageTasks.add(_searchPage(source, query, page: page));
    }
    final pages = await Future.wait(pageTasks);
    for (final page in pages) {
      merged.addAll(page);
    }
    return _dedupe(merged);
  }

  Future<AggregatorMediaDetail> getDetailFromApi(
    AggregatorSourceConfig source,
    String id,
  ) async {
    Object? macCmsError;
    try {
      final detail = await _detailFromMacCms(source, id);
      if (detail.episodes.isNotEmpty || source.detail == null) {
        return detail;
      }
    } catch (e) {
      macCmsError = e;
      if (source.detail == null) {
        throw macCmsError;
      }
    }

    if (source.detail != null && source.detail!.isNotEmpty) {
      return _detailFromHtml(source, id);
    }
    throw macCmsError ?? StateError('详情解析失败');
  }

  Future<List<AggregatorSearchResult>> _searchPage(
    AggregatorSourceConfig source,
    String query, {
    required int page,
  }) async {
    final encoded = Uri.encodeQueryComponent(query);
    final url = page <= 1
        ? '${source.api}?ac=videolist&wd=$encoded'
        : '${source.api}?ac=videolist&wd=$encoded&pg=$page';
    final data = await _getJson(url);
    final list = _listFromResponse(data);
    return list
        .map((item) => _resultFromApiItem(source, item))
        .where((item) => item.title.trim().isNotEmpty)
        .toList();
  }

  Future<AggregatorMediaDetail> _detailFromMacCms(
    AggregatorSourceConfig source,
    String id,
  ) async {
    final url =
        '${source.api}?ac=videolist&ids=${Uri.encodeQueryComponent(id)}';
    final data = await _getJson(url);
    final list = _listFromResponse(data);
    if (list.isEmpty) {
      throw StateError('详情为空');
    }
    return _detailFromApiItem(source, id, list.first);
  }

  Future<AggregatorMediaDetail> _detailFromHtml(
    AggregatorSourceConfig source,
    String id,
  ) async {
    final detailBase = source.detail!.replaceFirst(RegExp(r'/$'), '');
    final url = '$detailBase/index.php/vod/detail/id/$id.html';
    final response = await _dio
        .get<String>(
          url,
          options: Options(
            headers: _headers,
            responseType: ResponseType.plain,
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        )
        .timeout(timeout);
    final html = response.data ?? '';
    final episodes = _episodesFromRaw(
      html,
      fallbackLineName: source.name,
      preferLargestGroup: false,
    );
    final title = _firstMatch(html, RegExp(r'<h1[^>]*>([^<]+)</h1>')) ?? '';
    final poster =
        _firstMatch(html, RegExp(r'''(https?:\/\/[^"'\s<>]+?\.jpg)''')) ?? '';
    final year = _firstMatch(html, RegExp(r'>(\d{4})<'));
    final desc = _cleanHtml(
      _firstMatch(
            html,
            RegExp(r'''<div[^>]*class=["']sketch["'][^>]*>([\s\S]*?)</div>'''),
          ) ??
          '',
    );
    return AggregatorMediaDetail(
      source: source.key,
      sourceName: source.name,
      remoteId: id,
      title: title.isEmpty ? '未知影片' : title,
      year: year,
      poster: poster,
      desc: desc,
      episodes: episodes,
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _dio
        .get<String>(
          url,
          options: Options(
            headers: _headers,
            responseType: ResponseType.plain,
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        )
        .timeout(timeout);
    final raw = (response.data ?? '').trim();
    if (raw.isEmpty) {
      throw StateError('资源站返回空内容');
    }
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      final preview = raw.replaceAll(RegExp(r'\s+'), ' ');
      throw StateError(
        preview.startsWith('<') ? '资源站返回 HTML 页面' : '资源站返回内容不是 JSON',
      );
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('资源站返回 JSON 不是对象');
  }

  List<Map<String, dynamic>> _listFromResponse(Map<String, dynamic> data) {
    final list = data['list'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  AggregatorSearchResult _resultFromApiItem(
    AggregatorSourceConfig source,
    Map<String, dynamic> item,
  ) {
    final raw = (item['vod_play_url'] ?? '').toString();
    final episodes = _episodesFromRaw(raw, fallbackLineName: source.name);
    return AggregatorSearchResult(
      source: source.key,
      sourceName: source.name,
      remoteId: (item['vod_id'] ?? '').toString(),
      title: _compactText(item['vod_name']),
      year: _year(item['vod_year']),
      poster: _compactText(item['vod_pic']),
      category: _compactText(item['vod_class']),
      remarks: _compactText(item['vod_remarks']),
      desc: _cleanHtml((item['vod_content'] ?? '').toString()),
      typeName: _compactText(item['type_name']),
      doubanId: int.tryParse('${item['vod_douban_id'] ?? ''}'),
      episodes: episodes,
    );
  }

  AggregatorMediaDetail _detailFromApiItem(
    AggregatorSourceConfig source,
    String id,
    Map<String, dynamic> item,
  ) {
    final raw = (item['vod_play_url'] ?? '').toString();
    var episodes = _episodesFromRaw(raw, fallbackLineName: source.name);
    if (episodes.isEmpty) {
      episodes = _episodesFromRaw(
        (item['vod_content'] ?? '').toString(),
        fallbackLineName: source.name,
      );
    }
    return AggregatorMediaDetail(
      source: source.key,
      sourceName: source.name,
      remoteId: id,
      title: _compactText(item['vod_name']),
      year: _year(item['vod_year']),
      poster: _compactText(item['vod_pic']),
      desc: _cleanHtml((item['vod_content'] ?? '').toString()),
      category: _compactText(item['vod_class']),
      typeName: _compactText(item['type_name']),
      doubanId: int.tryParse('${item['vod_douban_id'] ?? ''}'),
      episodes: episodes,
    );
  }

  List<AggregatorEpisode> _episodesFromRaw(
    String raw, {
    required String fallbackLineName,
    bool preferLargestGroup = true,
  }) {
    if (raw.trim().isEmpty) return const [];
    final groups = raw.split(r'$$$');
    final parsedGroups = groups
        .map(
          (group) =>
              _parseEpisodeGroup(group, fallbackLineName: fallbackLineName),
        )
        .where((group) => group.isNotEmpty)
        .toList();
    if (parsedGroups.isEmpty) return const [];
    if (!preferLargestGroup) {
      return _dedupeEpisodes(parsedGroups.expand((item) => item).toList());
    }
    parsedGroups.sort((a, b) => b.length.compareTo(a.length));
    return _dedupeEpisodes(parsedGroups.first);
  }

  List<AggregatorEpisode> _parseEpisodeGroup(
    String group, {
    required String fallbackLineName,
  }) {
    final parts = group.split('#');
    final episodes = <AggregatorEpisode>[];
    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      final dollar = part.indexOf(r'$');
      String name;
      String url;
      if (dollar >= 0 && dollar + 1 < part.length) {
        name = part.substring(0, dollar).trim();
        url = part.substring(dollar + 1).trim();
      } else {
        name = '第${episodes.length + 1}集';
        url = _firstPlayableUrl(part) ?? '';
      }
      url = _cleanPlayableUrl(url);
      if (!_isDirectPlayable(url)) continue;
      episodes.add(
        AggregatorEpisode(
          index: episodes.length,
          name: name.isEmpty ? '第${episodes.length + 1}集' : name,
          url: url,
          lineName: fallbackLineName,
        ),
      );
    }

    if (episodes.isNotEmpty) return episodes;

    final matches = _playableUrlPattern
        .allMatches(group)
        .map((item) => _cleanPlayableUrl(item.group(0) ?? ''))
        .where(_isDirectPlayable)
        .toSet()
        .toList();
    return [
      for (var i = 0; i < matches.length; i++)
        AggregatorEpisode(
          index: i,
          name: '第${i + 1}集',
          url: matches[i],
          lineName: fallbackLineName,
        ),
    ];
  }

  List<AggregatorEpisode> _dedupeEpisodes(List<AggregatorEpisode> episodes) {
    final seen = <String>{};
    final result = <AggregatorEpisode>[];
    for (final episode in episodes) {
      if (seen.add(episode.url)) {
        result.add(
          AggregatorEpisode(
            index: result.length,
            name: episode.name,
            url: episode.url,
            lineName: episode.lineName,
            headers: episode.headers,
          ),
        );
      }
    }
    return result;
  }

  List<AggregatorSearchResult> _dedupe(List<AggregatorSearchResult> results) {
    final seen = <String>{};
    return [
      for (final item in results)
        if (seen.add(item.identity)) item,
    ];
  }

  String _cleanPlayableUrl(String url) {
    var value = url.trim();
    if (value.startsWith(r'$')) value = value.substring(1);
    final paren = value.indexOf('(');
    if (paren > 0) value = value.substring(0, paren);
    return value.trim();
  }

  String? _firstPlayableUrl(String raw) =>
      _playableUrlPattern.firstMatch(raw)?.group(0);

  bool _isDirectPlayable(String url) {
    final lower = url.toLowerCase();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.contains('.m3u8') || lower.contains('.mp4'));
  }

  String _cleanHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _compactText(Object? value) =>
      (value ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ');

  String? _year(Object? value) {
    final match = RegExp(r'\d{4}').firstMatch((value ?? '').toString());
    return match?.group(0);
  }

  String? _firstMatch(String value, RegExp pattern) =>
      pattern.firstMatch(value)?.group(1);

  static final RegExp _playableUrlPattern = RegExp(
    r'''https?:\/\/[^\s"'<>$#]+?\.(?:m3u8|mp4)(?:\?[^\s"'<>$#]*)?''',
    caseSensitive: false,
  );
}
