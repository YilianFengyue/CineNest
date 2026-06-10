import '../../../../utils/storage.dart';
import '../models/media_models.dart';

class SearchCacheRepository {
  static const String _prefix = 'mediaAggregator.searchCache.';
  static const Duration defaultTtl = Duration(hours: 2);

  Future<void> save(
    String keyword,
    List<AggregatorSearchResult> results,
  ) async {
    await GStorage.localCache.put(_key(keyword), {
      'savedAt': DateTime.now().toIso8601String(),
      'results': results.map((item) => item.toJson()).toList(),
    });
  }

  List<AggregatorSearchResult> readFresh(
    String keyword, {
    Duration ttl = defaultTtl,
  }) {
    final raw = GStorage.localCache.get(_key(keyword));
    if (raw is! Map) return const [];
    final savedAt = DateTime.tryParse('${raw['savedAt'] ?? ''}');
    if (savedAt == null || DateTime.now().difference(savedAt) > ttl) {
      return const [];
    }
    final list = raw['results'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map(
          (item) =>
              AggregatorSearchResult.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> clearKeyword(String keyword) =>
      GStorage.localCache.delete(_key(keyword));

  String _key(String keyword) =>
      '$_prefix${keyword.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), ' ')}';
}
