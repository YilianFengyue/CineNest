import '../models/source_config.dart';
import '../repositories/source_config_repository.dart';
import '../repositories/source_health_repository.dart';

class MoonTvSourceRegistry {
  MoonTvSourceRegistry({
    SourceConfigRepository? sourceRepository,
    SourceHealthRepository? healthRepository,
  }) : _sourceRepository = sourceRepository ?? SourceConfigRepository(),
       _healthRepository = healthRepository ?? SourceHealthRepository();

  final SourceConfigRepository _sourceRepository;
  final SourceHealthRepository _healthRepository;

  Future<List<AggregatorSourceConfig>> loadAll() async {
    final sources = await _sourceRepository.loadSources();
    final health = _healthRepository.loadAll();
    sources.sort((a, b) {
      final healthCompare = (health[a.key]?.rankPenalty ?? 12).compareTo(
        health[b.key]?.rankPenalty ?? 12,
      );
      if (healthCompare != 0) return healthCompare;
      final orderCompare = a.order.compareTo(b.order);
      return orderCompare != 0 ? orderCompare : a.name.compareTo(b.name);
    });
    return sources;
  }

  Future<List<AggregatorSourceConfig>> loadEnabled() async {
    final all = await loadAll();
    return all.where((source) => source.enabled).toList();
  }

  Future<AggregatorSourceConfig> requireSource(String key) async {
    final all = await loadAll();
    return all.firstWhere(
      (source) => source.key == key,
      orElse: () => throw StateError('未找到视频源：$key'),
    );
  }

  Future<void> setEnabled(String key, bool enabled) =>
      _sourceRepository.setSourceEnabled(key, enabled);

  Future<void> resetSources() => _sourceRepository.resetToSeed();
}
