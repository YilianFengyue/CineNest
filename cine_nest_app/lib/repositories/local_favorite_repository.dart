import 'dart:convert';
import 'package:cine_nest/utils/storage.dart';

class FavoriteRecord {
  final String id;
  final String title;
  final String? cover;
  final String? year;
  final String source;
  final String sourceName;
  final int episodeCount;
  final int savedAt;
  final List<String> tags;

  const FavoriteRecord({
    required this.id,
    required this.title,
    this.cover,
    this.year,
    required this.source,
    required this.sourceName,
    this.episodeCount = 0,
    int? savedAt,
    this.tags = const [],
  }) : savedAt = savedAt ?? 0;

  String get key => '$source:$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cover': cover,
        'year': year,
        'source': source,
        'sourceName': sourceName,
        'episodeCount': episodeCount,
        'savedAt': savedAt,
        'tags': tags,
      };

  factory FavoriteRecord.fromJson(Map<String, dynamic> json) => FavoriteRecord(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        cover: json['cover']?.toString(),
        year: json['year']?.toString(),
        source: json['source']?.toString() ?? '',
        sourceName: json['sourceName']?.toString() ?? '',
        episodeCount: json['episodeCount'] as int? ?? 0,
        savedAt: json['savedAt'] as int? ?? 0,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      );
}

class LocalFavoriteRepository {
  static const _boxKey = 'mediaFavorites';

  List<FavoriteRecord> loadAll() {
    final raw = GStorage.localCache.get(_boxKey);
    if (raw == null) return [];
    final list = (raw is String ? jsonDecode(raw) : raw) as List;
    return list
        .map((e) =>
            FavoriteRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  bool isFavorite(String key) {
    return loadAll().any((r) => r.key == key);
  }

  Future<void> toggle(FavoriteRecord record) async {
    final all = loadAll();
    final exists = all.any((r) => r.key == record.key);
    if (exists) {
      all.removeWhere((r) => r.key == record.key);
    } else {
      all.insert(0, record);
    }
    await _persist(all);
  }

  Future<void> remove(String key) async {
    final all = loadAll();
    all.removeWhere((r) => r.key == key);
    await _persist(all);
  }

  Future<void> clear() async {
    await GStorage.localCache.delete(_boxKey);
  }

  String exportJson() {
    return jsonEncode(loadAll().map((r) => r.toJson()).toList());
  }

  Future<void> _persist(List<FavoriteRecord> records) async {
    await GStorage.localCache.put(
      _boxKey,
      records.map((r) => r.toJson()).toList(),
    );
  }
}
