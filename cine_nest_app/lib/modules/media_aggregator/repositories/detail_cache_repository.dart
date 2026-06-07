import '../../../../utils/storage.dart';

class DetailCacheRepository {
  static const String _prefix = 'mediaAggregator.detailCache.';
  static const Duration defaultTtl = Duration(hours: 6);

  Future<void> save(String identity, Map<String, dynamic> detailJson) async {
    await GStorage.localCache.put(_key(identity), {
      'savedAt': DateTime.now().toIso8601String(),
      'detail': detailJson,
    });
  }

  Map<String, dynamic>? readFresh(
    String identity, {
    Duration ttl = defaultTtl,
  }) {
    final raw = GStorage.localCache.get(_key(identity));
    if (raw is! Map) return null;
    final savedAt = DateTime.tryParse('${raw['savedAt'] ?? ''}');
    if (savedAt == null || DateTime.now().difference(savedAt) > ttl) {
      return null;
    }
    final detail = raw['detail'];
    if (detail is! Map) return null;
    return Map<String, dynamic>.from(detail);
  }

  Future<void> clear(String identity) =>
      GStorage.localCache.delete(_key(identity));

  String _key(String identity) => '$_prefix$identity';
}
