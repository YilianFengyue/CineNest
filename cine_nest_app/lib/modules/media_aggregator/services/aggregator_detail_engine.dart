import '../models/media_models.dart';
import '../repositories/detail_cache_repository.dart';
import 'moontv_downstream.dart';
import 'moontv_source_registry.dart';
import 'source_preflight_service.dart';
import 'tmdb_enrichment_service.dart';

class AggregatorDetailEngine {
  AggregatorDetailEngine({
    MoonTvSourceRegistry? registry,
    MoonTvDownstream? downstream,
    DetailCacheRepository? cacheRepository,
    SourcePreflightService? preflightService,
    TmdbEnrichmentService? enrichmentService,
  }) : _registry = registry ?? MoonTvSourceRegistry(),
       _downstream = downstream ?? MoonTvDownstream(),
       _cacheRepository = cacheRepository ?? DetailCacheRepository(),
       _preflightService = preflightService ?? SourcePreflightService(),
       _enrichmentService = enrichmentService ?? const TmdbEnrichmentService();

  final MoonTvSourceRegistry _registry;
  final MoonTvDownstream _downstream;
  final DetailCacheRepository _cacheRepository;
  final SourcePreflightService _preflightService;
  final TmdbEnrichmentService _enrichmentService;

  Future<AggregatorMediaDetail> loadDetail(
    AggregatorSearchResult result, {
    bool useCache = true,
    bool enrichTmdb = true,
  }) async {
    if (useCache) {
      final cached = _cacheRepository.readFresh(result.identity);
      if (cached != null) {
        return AggregatorMediaDetail.fromJson(cached);
      }
    }

    final source = await _registry.requireSource(result.source);
    var detail = await _downstream.getDetailFromApi(source, result.remoteId);
    if (detail.episodes.isEmpty && result.episodes.isNotEmpty) {
      detail = detail.copyWith(episodes: result.episodes);
    }
    if (enrichTmdb) {
      final tmdb = await _enrichmentService.enrich(
        title: detail.title,
        year: detail.year,
        mediaKind: detail.episodes.length > 2 ? 'tv' : 'movie',
      );
      if (tmdb != null) {
        detail = detail.copyWith(tmdb: tmdb);
      }
    }
    await _cacheRepository.save(result.identity, detail.toJson());
    return detail;
  }

  Future<AggregatorPlaySession> buildPlaySession(
    AggregatorMediaDetail detail, {
    int episodeIndex = 0,
    bool preflight = true,
  }) async {
    final playableEpisodes = detail.episodes
        .where((episode) => episode.isPlayableDirectUrl)
        .toList();
    if (playableEpisodes.isEmpty) {
      throw StateError('未找到可播放直链');
    }
    final safeIndex = episodeIndex
        .clamp(0, playableEpisodes.length - 1)
        .toInt();
    var episode = playableEpisodes[safeIndex];

    if (preflight) {
      final probe = await _preflightService.probe(
        episode.url,
        headers: episode.headers,
      );
      if (!probe.ok && playableEpisodes.length > 1) {
        for (final candidate in playableEpisodes) {
          if (candidate.url == episode.url) continue;
          final nextProbe = await _preflightService.probe(
            candidate.url,
            headers: candidate.headers,
          );
          if (nextProbe.ok) {
            episode = candidate;
            break;
          }
        }
      }
    }

    return AggregatorPlaySession(
      title: '${detail.title} · ${episode.name}',
      source: detail.source,
      sourceName: detail.sourceName,
      remoteId: detail.remoteId,
      episodeIndex: episode.index,
      episodes: playableEpisodes,
      playUrl: episode.url,
      cover: detail.bestPoster,
      headers: episode.headers,
    );
  }
}
