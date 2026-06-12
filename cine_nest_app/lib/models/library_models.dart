/// PC 影视库（GET /api/library）响应模型。
///
/// 后端分三组：movies（电影）、shows（剧集，含集列表）、unmatched（TMDB
/// 没匹配上的，照常可播）。海报优先用 [posterProxy]（后端代理，手机不用翻墙）。
library;

class LibraryFile {
  const LibraryFile({
    required this.id,
    required this.filename,
    required this.relativePath,
    required this.size,
    required this.modifiedAt,
    required this.streamUrl,
  });

  final String id;
  final String filename;
  final String relativePath;
  final int size;
  final String modifiedAt;
  final String streamUrl;

  factory LibraryFile.fromJson(Map<String, dynamic> json) => LibraryFile(
        id: json['id']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        relativePath: json['relative_path']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        modifiedAt: json['modified_at']?.toString() ?? '',
        streamUrl: json['stream_url']?.toString() ?? '',
      );
}

class LibraryMeta {
  const LibraryMeta({
    required this.title,
    required this.year,
    required this.poster,
    required this.posterProxy,
    required this.overview,
    required this.vote,
  });

  final String title;
  final String year;
  final String poster;
  final String posterProxy;
  final String overview;
  final double vote;

  factory LibraryMeta.fromJson(Map<String, dynamic> json) => LibraryMeta(
        title: json['title']?.toString() ?? '',
        year: json['year']?.toString() ?? '',
        poster: json['poster']?.toString() ?? '',
        posterProxy: json['poster_proxy']?.toString() ?? '',
        overview: json['overview']?.toString() ?? '',
        vote: (json['vote'] as num?)?.toDouble() ?? 0,
      );
}

class LibraryMovie {
  const LibraryMovie({required this.meta, required this.file});

  final LibraryMeta meta;
  final LibraryFile file;

  factory LibraryMovie.fromJson(Map<String, dynamic> json) => LibraryMovie(
        meta: LibraryMeta.fromJson(json),
        file: LibraryFile.fromJson(json),
      );
}

class LibraryEpisode {
  const LibraryEpisode({
    required this.file,
    required this.episodeLabel,
    this.season,
    this.episode,
  });

  final LibraryFile file;
  final String episodeLabel;
  final int? season;
  final int? episode;

  factory LibraryEpisode.fromJson(Map<String, dynamic> json) => LibraryEpisode(
        file: LibraryFile.fromJson(json),
        episodeLabel: json['episode_label']?.toString() ?? '',
        season: (json['season'] as num?)?.toInt(),
        episode: (json['episode'] as num?)?.toInt(),
      );
}

class LibraryShow {
  const LibraryShow({required this.meta, required this.episodes});

  final LibraryMeta meta;
  final List<LibraryEpisode> episodes;

  factory LibraryShow.fromJson(Map<String, dynamic> json) => LibraryShow(
        meta: LibraryMeta.fromJson(json),
        episodes: (json['episodes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => LibraryEpisode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class LibraryUnmatched {
  const LibraryUnmatched({required this.file, required this.parsedTitle});

  final LibraryFile file;
  final String parsedTitle;

  factory LibraryUnmatched.fromJson(Map<String, dynamic> json) =>
      LibraryUnmatched(
        file: LibraryFile.fromJson(json),
        parsedTitle: json['parsed_title']?.toString() ?? '',
      );
}

class LibraryView {
  const LibraryView({
    required this.movies,
    required this.shows,
    required this.unmatched,
    required this.total,
    required this.root,
  });

  final List<LibraryMovie> movies;
  final List<LibraryShow> shows;
  final List<LibraryUnmatched> unmatched;
  final int total;
  final String root;

  bool get isEmpty => total == 0;

  factory LibraryView.fromJson(Map<String, dynamic> json) => LibraryView(
        movies: (json['movies'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => LibraryMovie.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        shows: (json['shows'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => LibraryShow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        unmatched: (json['unmatched'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => LibraryUnmatched.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        root: json['root']?.toString() ?? '',
      );
}
