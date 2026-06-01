import 'package:cine_nest/models/movie.dart';

/// AI 推荐帖子卡片（共享契约，对应 F1 帖子流）。
///
/// 由 PC 端 Agent 生成：一条 Post 包裹一部 [movie] + AI 推荐理由 + 可看性标识。
class Post {
  final Movie movie;
  final String recommendReason; // AI 一句话推荐理由
  final bool hasVideoSource; // 是否有在线播放源
  final bool hasBilibili; // 是否有 B站解说
  final String? posterUrl; // C 生成的 Micro Design 海报（F8），为空则用 movie.posterUrl

  const Post({
    required this.movie,
    this.recommendReason = '',
    this.hasVideoSource = false,
    this.hasBilibili = false,
    this.posterUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
    recommendReason: json['recommend_reason'] as String? ?? '',
    hasVideoSource: json['has_video_source'] as bool? ?? false,
    hasBilibili: json['has_bilibili'] as bool? ?? false,
    posterUrl: json['poster_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'movie': movie.toJson(),
    'recommend_reason': recommendReason,
    'has_video_source': hasVideoSource,
    'has_bilibili': hasBilibili,
    'poster_url': posterUrl,
  };
}
