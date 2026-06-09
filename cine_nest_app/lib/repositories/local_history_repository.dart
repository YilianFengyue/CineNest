import 'dart:convert';
import 'package:cine_nest/utils/storage.dart';

class HistoryRecord {
  final String id;
  final String title;
  final String? cover;
  final String? year;
  final String source;
  final String sourceName;
  final String? episodeName;
  final int episodeIndex;
  final int positionMs;
  final int durationMs;
  final int savedAt;
  final List<String> tags;

  const HistoryRecord({
    required this.id,
    required this.title,
    this.cover,
    this.year,
    required this.source,
    required this.sourceName,
    this.episodeName,
    this.episodeIndex = 0,
    this.positionMs = 0,
    this.durationMs = 0,
    int? savedAt,
    this.tags = const [],
  }) : savedAt = savedAt ?? 0;

  String get key => '$source:$id';
  double get progress =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cover': cover,
        'year': year,
        'source': source,
        'sourceName': sourceName,
        'episodeName': episodeName,
        'episodeIndex': episodeIndex,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'savedAt': savedAt,
        'tags': tags,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        cover: json['cover']?.toString(),
        year: json['year']?.toString(),
        source: json['source']?.toString() ?? '',
        sourceName: json['sourceName']?.toString() ?? '',
        episodeName: json['episodeName']?.toString(),
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        positionMs: json['positionMs'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        savedAt: json['savedAt'] as int? ?? 0,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      );
}

class LocalHistoryRepository {
  static const _boxKey = 'mediaHistory';

  List<HistoryRecord> loadAll() {
    final raw = GStorage.localCache.get(_boxKey);
    if (raw == null) return [];
    final list = (raw is String ? jsonDecode(raw) : raw) as List;
    return list
        .map((e) => HistoryRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  HistoryRecord? get(String key) {
    final all = loadAll();
    try {
      return all.firstWhere((r) => r.key == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(HistoryRecord record) async {
    final all = loadAll();
    all.removeWhere((r) => r.key == record.key);
    all.insert(0, record);
    if (all.length > 200) all.removeRange(200, all.length);
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

  Future<void> _persist(List<HistoryRecord> records) async {
    await GStorage.localCache.put(
      _boxKey,
      records.map((r) => r.toJson()).toList(),
    );
  }
}
