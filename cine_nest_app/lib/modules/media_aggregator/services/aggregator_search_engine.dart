import 'dart:async';

import '../models/media_models.dart';
import '../models/source_config.dart';
import '../repositories/search_cache_repository.dart';
import '../repositories/source_health_repository.dart';
import 'moontv_downstream.dart';
import 'moontv_source_registry.dart';
import 'source_ranker.dart';
import 'tmdb_enrichment_service.dart';

class AggregatorSearchEngine {
  AggregatorSearchEngine({
    MoonTvSourceRegistry? registry,
    MoonTvDownstream? downstream,
    SourceHealthRepository? healthRepository,
    SearchCacheRepository? cacheRepository,
    SourceRanker? ranker,
    TmdbEnrichmentService? enrichmentService,
    this.maxConcurrency = 6,
    this.enableTmdbEnrichment = false,
  }) : _registry = registry ?? MoonTvSourceRegistry(),
       _downstream = downstream ?? MoonTvDownstream(),
       _healthRepository = healthRepository ?? SourceHealthRepository(),
       _cacheRepository = cacheRepository ?? SearchCacheRepository(),
       _ranker = ranker ?? SourceRanker(),
       _enrichmentService = enrichmentService ?? const TmdbEnrichmentService();

  final MoonTvSourceRegistry _registry;
  final MoonTvDownstream _downstream;
  final SourceHealthRepository _healthRepository;
  final SearchCacheRepository _cacheRepository;
  final SourceRanker _ranker;
  final TmdbEnrichmentService _enrichmentService;
  final int maxConcurrency;
  final bool enableTmdbEnrichment;

  Stream<AggregatorSearchBatch> search(
    String keyword, {
    bool useCache = true,
    int maxPagesPerSource = 1,
  }) async* {
    final query = keyword.trim();
    if (query.isEmpty) {
      yield const AggregatorSearchBatch(
        keyword: '',
        results: [],
        traces: [],
        completedSources: 0,
        totalSources: 0,
        searching: false,
      );
      return;
    }

    final cached = useCache
        ? _cacheRepository.readFresh(query)
        : const <AggregatorSearchResult>[];
    if (cached.isNotEmpty) {
      yield AggregatorSearchBatch(
        keyword: query,
        results: _ranker.rank(query, cached),
        traces: const [],
        completedSources: 0,
        totalSources: 0,
        searching: true,
        fromCache: true,
      );
    }

    final sources = await _registry.loadEnabled();
    final total = sources.length;
    if (total == 0) {
      yield AggregatorSearchBatch(
        keyword: query,
        results: cached,
        traces: const [],
        completedSources: 0,
        totalSources: 0,
        searching: false,
      );
      return;
    }

    final results = <String, AggregatorSearchResult>{
      for (final item in cached) item.identity: item,
    };
    final traces = <ProviderSearchTrace>[];
    final pending = <int, Future<_SourceSearchResult>>{};
    var cursor = 0;
    var completed = 0;

    void enqueue() {
      while (cursor < total && pending.length < maxConcurrency) {
        final source = sources[cursor];
        final taskId = cursor++;
        pending[taskId] = _searchOne(
          taskId: taskId,
          source: source,
          keyword: query,
          maxPages: maxPagesPerSource,
        );
      }
    }

    enqueue();
    while (pending.isNotEmpty) {
      final done = await Future.any(pending.values);
      pending.remove(done.taskId);
      completed++;
      traces.add(done.trace);

      for (final item in done.results) {
        results[item.identity] = item;
      }

      yield AggregatorSearchBatch(
        keyword: query,
        results: _ranker.rank(query, results.values),
        traces: List.unmodifiable(traces),
        completedSources: completed,
        totalSources: total,
        searching: completed < total,
      );

      enqueue();
    }

    final finalResults = _ranker.rank(query, results.values);
    await _cacheRepository.save(query, finalResults);
    yield AggregatorSearchBatch(
      keyword: query,
      results: finalResults,
      traces: List.unmodifiable(traces),
      completedSources: completed,
      totalSources: total,
      searching: false,
    );
  }

  Future<_SourceSearchResult> _searchOne({
    required int taskId,
    required AggregatorSourceConfig source,
    required String keyword,
    required int maxPages,
  }) async {
    final sw = Stopwatch()..start();
    try {
      var items = await _downstream.searchFromApi(
        source,
        keyword,
        maxPages: maxPages,
      );
      final health = await _healthRepository.recordSuccess(
        source: source.key,
        sourceName: source.name,
        elapsedMs: sw.elapsedMilliseconds,
      );
      items = items
          .where((item) => _passesContentFilter(item))
          .map((item) => item.copyWith(health: health))
          .toList();
      if (enableTmdbEnrichment && items.isNotEmpty) {
        items = await _enrichTopItems(
          items,
        ).timeout(const Duration(seconds: 3), onTimeout: () => items);
      }
      return _SourceSearchResult(
        taskId: taskId,
        results: items,
        trace: ProviderSearchTrace(
          source: source.key,
          sourceName: source.name,
          ok: true,
          elapsedMs: sw.elapsedMilliseconds,
          resultCount: items.length,
        ),
      );
    } catch (e) {
      await _healthRepository.recordFailure(
        source: source.key,
        sourceName: source.name,
        error: _friendlyError(e),
        elapsedMs: sw.elapsedMilliseconds,
      );
      return _SourceSearchResult(
        taskId: taskId,
        results: const [],
        trace: ProviderSearchTrace(
          source: source.key,
          sourceName: source.name,
          ok: false,
          elapsedMs: sw.elapsedMilliseconds,
          error: _friendlyError(e),
        ),
      );
    }
  }

  Future<List<AggregatorSearchResult>> _enrichTopItems(
    List<AggregatorSearchResult> items,
  ) async {
    final next = [...items];
    final count = next.length > 4 ? 4 : next.length;
    for (var i = 0; i < count; i++) {
      final item = next[i];
      final tmdb = await _enrichmentService.enrich(
        title: item.title,
        year: item.year,
        mediaKind: item.episodeCount > 2 ? 'tv' : 'movie',
      );
      if (tmdb != null) {
        next[i] = item.copyWith(tmdb: tmdb);
      }
    }
    return next;
  }

  bool _passesContentFilter(AggregatorSearchResult item) {
    final haystack =
        '${item.title} ${item.category ?? ''} ${item.typeName ?? ''}';
    const blocked = ['伦理', '写真', '福利'];
    return !blocked.any(haystack.contains);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('TimeoutException') || raw.contains('timeout')) {
      return '请求超时';
    }
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return '网络连接失败';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }
}

class _SourceSearchResult {
  const _SourceSearchResult({
    required this.taskId,
    required this.results,
    required this.trace,
  });

  final int taskId;
  final List<AggregatorSearchResult> results;
  final ProviderSearchTrace trace;
}
