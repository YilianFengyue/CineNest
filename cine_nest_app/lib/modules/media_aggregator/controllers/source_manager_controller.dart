import 'package:get/get.dart';

import '../models/source_config.dart';
import '../models/source_health.dart';
import '../repositories/source_health_repository.dart';
import '../services/moontv_source_registry.dart';

class SourceManagerController extends GetxController {
  SourceManagerController({
    MoonTvSourceRegistry? registry,
    SourceHealthRepository? healthRepository,
  }) : _registry = registry ?? MoonTvSourceRegistry(),
       _healthRepository = healthRepository ?? SourceHealthRepository();

  final MoonTvSourceRegistry _registry;
  final SourceHealthRepository _healthRepository;

  final sources = <AggregatorSourceConfig>[].obs;
  final health = <String, SourceHealthSnapshot>{}.obs;
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    loading.value = true;
    try {
      sources.assignAll(await _registry.loadAll());
      health.assignAll(_healthRepository.loadAll());
    } finally {
      loading.value = false;
    }
  }

  Future<void> setEnabled(AggregatorSourceConfig source, bool enabled) async {
    await _registry.setEnabled(source.key, enabled);
    await reload();
  }

  Future<void> resetSources() async {
    await _registry.resetSources();
    await reload();
  }

  Future<void> clearHealth() async {
    await _healthRepository.clear();
    await reload();
  }
}
