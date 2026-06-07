import '../../../../utils/storage.dart';
import '../models/source_health.dart';

class SourceHealthRepository {
  static const String _key = 'mediaAggregator.sourceHealth';

  Map<String, SourceHealthSnapshot> loadAll() {
    final raw = GStorage.localCache.get(_key);
    if (raw is! Map) return {};
    return raw.map((key, value) {
      if (value is Map) {
        return MapEntry(
          key.toString(),
          SourceHealthSnapshot.fromJson(Map<String, dynamic>.from(value)),
        );
      }
      return MapEntry(
        key.toString(),
        SourceHealthSnapshot.empty(key.toString()),
      );
    });
  }

  SourceHealthSnapshot get(String source, {String sourceName = ''}) {
    return loadAll()[source] ??
        SourceHealthSnapshot.empty(source, sourceName: sourceName);
  }

  Future<SourceHealthSnapshot> recordSuccess({
    required String source,
    required String sourceName,
    required int elapsedMs,
  }) async {
    final all = loadAll();
    final current =
        all[source] ??
        SourceHealthSnapshot.empty(source, sourceName: sourceName);
    final next = current.recordSuccess(
      sourceName: sourceName,
      elapsedMs: elapsedMs,
    );
    all[source] = next;
    await _save(all);
    return next;
  }

  Future<SourceHealthSnapshot> recordFailure({
    required String source,
    required String sourceName,
    required String error,
    int? elapsedMs,
  }) async {
    final all = loadAll();
    final current =
        all[source] ??
        SourceHealthSnapshot.empty(source, sourceName: sourceName);
    final next = current.recordFailure(
      sourceName: sourceName,
      error: error,
      elapsedMs: elapsedMs,
    );
    all[source] = next;
    await _save(all);
    return next;
  }

  Future<void> clear() => GStorage.localCache.delete(_key);

  Future<void> _save(Map<String, SourceHealthSnapshot> all) async {
    await GStorage.localCache.put(
      _key,
      all.map((key, value) => MapEntry(key, value.toJson())),
    );
  }
}
