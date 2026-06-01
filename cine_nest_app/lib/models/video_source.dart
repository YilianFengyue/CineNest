/// 视频源（共享契约，对应 F4 视频源解析引擎 / F3 播放器）。
class VideoSource {
  final String id; // 源标识
  final String name; // 源名称（如「B站解说」「线路1」）
  final String? quality; // 清晰度（如 1080P）
  final SourceType type;
  final String? playUrl; // 解析后的可播放地址（m3u8/mp4），未解析时为空

  // B站相关元信息（type == bilibili 时）
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
  web, // 第三方在线源
  bilibili, // B站
  netdisk; // 网盘（F10 扩展）

  static SourceType fromString(String? s) => switch (s) {
    'bilibili' => SourceType.bilibili,
    'netdisk' => SourceType.netdisk,
    _ => SourceType.web,
  };
}
