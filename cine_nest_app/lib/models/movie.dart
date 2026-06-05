/// 电影数据模型（共享契约，对应后端 models/schemas.py 的 Movie）。
///
/// 字段对齐《需求与计划书》F2 电影详情页。
class Movie {
  final int id; // TMDB id
  final String title; // 中文标题
  final String? originalTitle; // 英文/原始标题
  final int? year;
  final List<String> genres; // 类型标签
  final double? rating; // TMDB 评分
  final String? overview; // 简介
  final String? posterUrl; // TMDB 海报
  final String? backdropUrl; // 背景图
  final List<String> directors;
  final List<String> cast;
  final bool isCollected;

  const Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.year,
    this.genres = const [],
    this.rating,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.directors = const [],
    this.cast = const [],
    this.isCollected = false,
  });

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    originalTitle: json['original_title'] as String?,
    year: json['year'] as int?,
    genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    rating: (json['rating'] as num?)?.toDouble(),
    overview: json['overview'] as String?,
    posterUrl: json['poster_url'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    directors: (json['directors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    cast: (json['cast'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    isCollected: json['is_collected'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'original_title': originalTitle,
    'year': year,
    'genres': genres,
    'rating': rating,
    'overview': overview,
    'poster_url': posterUrl,
    'backdrop_url': backdropUrl,
    'directors': directors,
    'cast': cast,
    'is_collected': isCollected,
  };
}
