class AggregatorSourceConfig {
  const AggregatorSourceConfig({
    required this.key,
    required this.name,
    required this.api,
    this.detail,
    this.from = 'config',
    this.disabled = false,
    this.order = 0,
  });

  final String key;
  final String name;
  final String api;
  final String? detail;
  final String from;
  final bool disabled;
  final int order;

  bool get enabled => !disabled;

  AggregatorSourceConfig copyWith({
    String? key,
    String? name,
    String? api,
    String? detail,
    String? from,
    bool? disabled,
    int? order,
  }) {
    return AggregatorSourceConfig(
      key: key ?? this.key,
      name: name ?? this.name,
      api: api ?? this.api,
      detail: detail ?? this.detail,
      from: from ?? this.from,
      disabled: disabled ?? this.disabled,
      order: order ?? this.order,
    );
  }

  factory AggregatorSourceConfig.fromJson(
    Map<String, dynamic> json, {
    String? key,
    int order = 0,
  }) {
    return AggregatorSourceConfig(
      key: (key ?? json['key'] ?? '').toString(),
      name: (json['name'] ?? key ?? '').toString(),
      api: (json['api'] ?? '').toString(),
      detail: json['detail']?.toString(),
      from: (json['from'] ?? 'config').toString(),
      disabled: json['disabled'] == true,
      order: _asInt(json['order']) ?? order,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'api': api,
    if (detail != null && detail!.isNotEmpty) 'detail': detail,
    'from': from,
    'disabled': disabled,
    'order': order,
  };

  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class SourceConfigBundle {
  const SourceConfigBundle({required this.cacheTime, required this.sources});

  final int cacheTime;
  final List<AggregatorSourceConfig> sources;

  factory SourceConfigBundle.fromMoonTvJson(Map<String, dynamic> json) {
    final rawSites = json['api_site'];
    final sites = rawSites is Map ? rawSites : const {};
    var order = 0;
    final sources = <AggregatorSourceConfig>[];
    for (final entry in sites.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      sources.add(
        AggregatorSourceConfig.fromJson(
          Map<String, dynamic>.from(value),
          key: entry.key.toString(),
          order: order++,
        ),
      );
    }
    return SourceConfigBundle(
      cacheTime: int.tryParse('${json['cache_time'] ?? ''}') ?? 7200,
      sources: sources,
    );
  }
}
