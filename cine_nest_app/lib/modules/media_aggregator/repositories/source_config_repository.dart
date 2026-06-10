import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../utils/storage.dart';
import '../models/source_config.dart';

class SourceConfigRepository {
  static const String _seedAsset = 'assets/sources/moontv_sources.json';
  static const String _overrideKey = 'mediaAggregator.sourceOverrides';

  Future<SourceConfigBundle> loadSeedBundle() async {
    final raw = await rootBundle.loadString(_seedAsset);
    return SourceConfigBundle.fromMoonTvJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<List<AggregatorSourceConfig>> loadSources() async {
    final seed = await loadSeedBundle();
    final overrides = _readOverrides();
    if (overrides.isEmpty) {
      return seed.sources;
    }

    final merged = <String, AggregatorSourceConfig>{
      for (final source in seed.sources) source.key: source,
    };
    for (final source in overrides) {
      merged[source.key] = source;
    }
    final sources = merged.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return sources;
  }

  Future<void> saveSources(List<AggregatorSourceConfig> sources) async {
    await GStorage.localCache.put(
      _overrideKey,
      sources.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> resetToSeed() async {
    await GStorage.localCache.delete(_overrideKey);
  }

  Future<void> setSourceEnabled(String key, bool enabled) async {
    final sources = await loadSources();
    final next = sources
        .map(
          (item) => item.key == key ? item.copyWith(disabled: !enabled) : item,
        )
        .toList();
    await saveSources(next);
  }

  List<AggregatorSourceConfig> _readOverrides() {
    final raw = GStorage.localCache.get(_overrideKey);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              AggregatorSourceConfig.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.key.isNotEmpty && item.api.isNotEmpty)
        .toList();
  }
}
