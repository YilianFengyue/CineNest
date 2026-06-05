/// Video source model for member A's source search and parse flow.
class VideoSource {
  final String id;
  final String name;
  final String? quality;
  final SourceType type;
  final String? playUrl;
  final String? cover;
  final int? playCount;
  final List<VideoEpisode> episodes;

  const VideoSource({
    required this.id,
    required this.name,
    this.quality,
    this.type = SourceType.web,
    this.playUrl,
    this.cover,
    this.playCount,
    this.episodes = const [],
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) => VideoSource(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    quality: json['quality'] as String?,
    type: SourceType.fromString(json['type'] as String?),
    playUrl: json['play_url'] as String?,
    cover: json['cover'] as String?,
    playCount: json['play_count'] as int?,
    episodes: _parseEpisodes(json['episodes']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quality': quality,
    'type': type.name,
    'play_url': playUrl,
    'cover': cover,
    'play_count': playCount,
    'episodes': episodes.map((episode) => episode.toJson()).toList(),
  };

  static List<VideoEpisode> _parseEpisodes(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => VideoEpisode.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class VideoEpisode {
  final int index;
  final String title;
  final String playUrl;

  const VideoEpisode({
    required this.index,
    required this.title,
    required this.playUrl,
  });

  factory VideoEpisode.fromJson(Map<String, dynamic> json) => VideoEpisode(
    index: json['index'] is int
        ? json['index'] as int
        : int.tryParse(json['index']?.toString() ?? '') ?? 0,
    title: json['title'] as String? ?? '',
    playUrl: json['play_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'play_url': playUrl,
  };
}

enum SourceType {
  web,
  bilibili,
  netdisk;

  static SourceType fromString(String? value) => switch (value) {
    'bilibili' => SourceType.bilibili,
    'netdisk' => SourceType.netdisk,
    _ => SourceType.web,
  };
}
