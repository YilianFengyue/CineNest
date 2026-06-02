/// Video source model for member A's source search and parse flow.
class VideoSource {
  final String id;
  final String name;
  final String? quality;
  final SourceType type;
  final String? playUrl;
  final String? cover;
  final int? playCount;

  const VideoSource({
    required this.id,
    required this.name,
    this.quality,
    this.type = SourceType.web,
    this.playUrl,
    this.cover,
    this.playCount,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) => VideoSource(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        quality: json['quality'] as String?,
        type: SourceType.fromString(json['type'] as String?),
        playUrl: json['play_url'] as String?,
        cover: json['cover'] as String?,
        playCount: json['play_count'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quality': quality,
        'type': type.name,
        'play_url': playUrl,
        'cover': cover,
        'play_count': playCount,
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
