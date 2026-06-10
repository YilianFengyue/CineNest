class LocalVideo {
  const LocalVideo({
    required this.id,
    required this.title,
    required this.filename,
    required this.relativePath,
    required this.size,
    required this.modifiedAt,
    required this.streamUrl,
  });

  final String id;
  final String title;
  final String filename;
  final String relativePath;
  final int size;
  final String modifiedAt;
  final String streamUrl;

  factory LocalVideo.fromJson(Map<String, dynamic> json) => LocalVideo(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        relativePath: json['relative_path']?.toString() ?? '',
        size: json['size'] is int
            ? json['size'] as int
            : int.tryParse(json['size']?.toString() ?? '') ?? 0,
        modifiedAt: json['modified_at']?.toString() ?? '',
        streamUrl: json['stream_url']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filename': filename,
        'relative_path': relativePath,
        'size': size,
        'modified_at': modifiedAt,
        'stream_url': streamUrl,
      };
}
