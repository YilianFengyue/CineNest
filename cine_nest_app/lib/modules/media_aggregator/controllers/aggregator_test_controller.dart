import 'dart:async';

import 'package:get/get.dart';

import '../models/media_models.dart';
import '../services/aggregator_search_engine.dart';

class AggregatorTestController extends GetxController {
  AggregatorTestController({AggregatorSearchEngine? searchEngine})
    : _searchEngine = searchEngine ?? AggregatorSearchEngine();

  final AggregatorSearchEngine _searchEngine;
  final keyword = ''.obs;
  final results = <AggregatorSearchResult>[].obs;
  final traces = <ProviderSearchTrace>[].obs;
  final searching = false.obs;
  final fromCache = false.obs;
  final completedSources = 0.obs;
  final totalSources = 0.obs;
  final lastError = ''.obs;

  StreamSubscription<AggregatorSearchBatch>? _sub;
  int _generation = 0;

  double get progress {
    final total = totalSources.value;
    return total == 0 ? 0 : completedSources.value / total;
  }

  Future<void> search(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    keyword.value = query;
    lastError.value = '';
    fromCache.value = false;
    searching.value = true;
    completedSources.value = 0;
    totalSources.value = 0;
    results.clear();
    traces.clear();

    await _sub?.cancel();
    final generation = ++_generation;
    _sub = _searchEngine
        .search(query)
        .listen(
          (batch) {
            if (generation != _generation) return;
            results.assignAll(batch.results);
            traces.assignAll(batch.traces);
            searching.value = batch.searching;
            fromCache.value = batch.fromCache;
            completedSources.value = batch.completedSources;
            totalSources.value = batch.totalSources;
          },
          onError: (Object e) {
            if (generation != _generation) return;
            lastError.value = _friendly(e);
            searching.value = false;
          },
          onDone: () {
            if (generation == _generation) searching.value = false;
          },
        );
  }

  Future<void> stopSearch() async {
    _generation++;
    await _sub?.cancel();
    searching.value = false;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  String _friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('TimeoutException')) return '搜索超时，已保留已返回结果';
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }
}
