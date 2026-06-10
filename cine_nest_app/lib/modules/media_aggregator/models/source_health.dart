enum SourceHealthLevel { unknown, good, slow, bad }

class SourceHealthSnapshot {
  const SourceHealthSnapshot({
    required this.source,
    this.sourceName = '',
    this.level = SourceHealthLevel.unknown,
    this.lastElapsedMs,
    this.averageElapsedMs,
    this.successCount = 0,
    this.failureCount = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastError,
  });

  final String source;
  final String sourceName;
  final SourceHealthLevel level;
  final int? lastElapsedMs;
  final int? averageElapsedMs;
  final int successCount;
  final int failureCount;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastError;

  bool get isDisabledCandidate =>
      level == SourceHealthLevel.bad && failureCount >= 3;

  int get rankPenalty {
    return switch (level) {
      SourceHealthLevel.good => 0,
      SourceHealthLevel.slow => 8,
      SourceHealthLevel.unknown => 12,
      SourceHealthLevel.bad => 40,
    };
  }

  SourceHealthSnapshot recordSuccess({
    required String sourceName,
    required int elapsedMs,
  }) {
    final nextSuccess = successCount + 1;
    final nextAverage = averageElapsedMs == null
        ? elapsedMs
        : (((averageElapsedMs! * successCount) + elapsedMs) / nextSuccess)
              .round();
    final nextLevel = nextAverage > 3500
        ? SourceHealthLevel.slow
        : SourceHealthLevel.good;
    return SourceHealthSnapshot(
      source: source,
      sourceName: sourceName,
      level: nextLevel,
      lastElapsedMs: elapsedMs,
      averageElapsedMs: nextAverage,
      successCount: nextSuccess,
      failureCount: failureCount,
      lastSuccessAt: DateTime.now(),
      lastFailureAt: lastFailureAt,
      lastError: null,
    );
  }

  SourceHealthSnapshot recordFailure({
    required String sourceName,
    required String error,
    int? elapsedMs,
  }) {
    final nextFailures = failureCount + 1;
    return SourceHealthSnapshot(
      source: source,
      sourceName: sourceName,
      level: nextFailures >= 3 ? SourceHealthLevel.bad : level,
      lastElapsedMs: elapsedMs ?? lastElapsedMs,
      averageElapsedMs: averageElapsedMs,
      successCount: successCount,
      failureCount: nextFailures,
      lastSuccessAt: lastSuccessAt,
      lastFailureAt: DateTime.now(),
      lastError: error,
    );
  }

  factory SourceHealthSnapshot.empty(String source, {String sourceName = ''}) {
    return SourceHealthSnapshot(source: source, sourceName: sourceName);
  }

  factory SourceHealthSnapshot.fromJson(Map<String, dynamic> json) {
    return SourceHealthSnapshot(
      source: (json['source'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '').toString(),
      level: SourceHealthLevel.values.firstWhere(
        (item) => item.name == json['level'],
        orElse: () => SourceHealthLevel.unknown,
      ),
      lastElapsedMs: _asInt(json['lastElapsedMs']),
      averageElapsedMs: _asInt(json['averageElapsedMs']),
      successCount: _asInt(json['successCount']) ?? 0,
      failureCount: _asInt(json['failureCount']) ?? 0,
      lastSuccessAt: _date(json['lastSuccessAt']),
      lastFailureAt: _date(json['lastFailureAt']),
      lastError: json['lastError']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'sourceName': sourceName,
    'level': level.name,
    'lastElapsedMs': lastElapsedMs,
    'averageElapsedMs': averageElapsedMs,
    'successCount': successCount,
    'failureCount': failureCount,
    'lastSuccessAt': lastSuccessAt?.toIso8601String(),
    'lastFailureAt': lastFailureAt?.toIso8601String(),
    'lastError': lastError,
  };

  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
