import 'source_health.dart';

class AggregatorEpisode {
  const AggregatorEpisode({
    required this.index,
    required this.name,
    required this.url,
    this.lineName,
    this.headers = const {},
  });

  final int index;
  final String name;
  final String url;
  final String? lineName;
  final Map<String, String> headers;

  bool get isPlayableDirectUrl {
    final lower = url.toLowerCase();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.contains('.m3u8') || lower.contains('.mp4'));
  }

  factory AggregatorEpisode.fromJson(Map<String, dynamic> json) {
    return AggregatorEpisode(
      index: int.tryParse('${json['index'] ?? ''}') ?? 0,
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      lineName: json['lineName']?.toString(),
      headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'name': name,
    'url': url,
    if (lineName != null) 'lineName': lineName,
    if (headers.isNotEmpty) 'headers': headers,
  };
}

class TmdbEnrichment {
  const TmdbEnrichment({
    this.tmdbId,
    this.title,
    this.originalTitle,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.rating,
    this.genres = const [],
    this.cast = const [],
  });

  final int? tmdbId;
  final String? title;
  final String? originalTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? overview;
  final double? rating;
  final List<String> genres;
  final List<String> cast;

  bool get hasUsefulImage =>
      (posterUrl != null && posterUrl!.isNotEmpty) ||
      (backdropUrl != null && backdropUrl!.isNotEmpty);

  factory TmdbEnrichment.fromJson(Map<String, dynamic> json) {
    return TmdbEnrichment(
      tmdbId: int.tryParse('${json['tmdbId'] ?? json['id'] ?? ''}'),
      title: json['title']?.toString(),
      originalTitle: json['originalTitle']?.toString(),
      posterUrl: json['posterUrl']?.toString(),
      backdropUrl: json['backdropUrl']?.toString(),
      overview: json['overview']?.toString(),
      rating: double.tryParse('${json['rating'] ?? ''}'),
      genres: (json['genres'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      cast: (json['cast'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tmdbId': tmdbId,
    'title': title,
    'originalTitle': originalTitle,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'overview': overview,
    'rating': rating,
    'genres': genres,
    'cast': cast,
  };
}

class AggregatorSearchResult {
  const AggregatorSearchResult({
    required this.source,
    required this.sourceName,
    required this.remoteId,
    required this.title,
    this.year,
    this.poster,
    this.category,
    this.remarks,
    this.desc,
    this.typeName,
    this.doubanId,
    this.episodes = const [],
    this.health,
    this.tmdb,
  });

  final String source;
  final String sourceName;
  final String remoteId;
  final String title;
  final String? year;
  final String? poster;
  final String? category;
  final String? remarks;
  final String? desc;
  final String? typeName;
  final int? doubanId;
  final List<AggregatorEpisode> episodes;
  final SourceHealthSnapshot? health;
  final TmdbEnrichment? tmdb;

  String get identity => '$source:$remoteId';
  int get episodeCount => episodes.length;
  bool get hasPlayableDirectUrl =>
      episodes.any((episode) => episode.isPlayableDirectUrl);
  String? get bestPoster =>
      tmdb?.posterUrl?.isNotEmpty == true ? tmdb!.posterUrl : poster;

  AggregatorSearchResult copyWith({
    List<AggregatorEpisode>? episodes,
    SourceHealthSnapshot? health,
    TmdbEnrichment? tmdb,
  }) {
    return AggregatorSearchResult(
      source: source,
      sourceName: sourceName,
      remoteId: remoteId,
      title: title,
      year: year,
      poster: poster,
      category: category,
      remarks: remarks,
      desc: desc,
      typeName: typeName,
      doubanId: doubanId,
      episodes: episodes ?? this.episodes,
      health: health ?? this.health,
      tmdb: tmdb ?? this.tmdb,
    );
  }

  factory AggregatorSearchResult.fromJson(Map<String, dynamic> json) {
    return AggregatorSearchResult(
      source: (json['source'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '').toString(),
      remoteId: (json['remoteId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      year: json['year']?.toString(),
      poster: json['poster']?.toString(),
      category: json['category']?.toString(),
      remarks: json['remarks']?.toString(),
      desc: json['desc']?.toString(),
      typeName: json['typeName']?.toString(),
      doubanId: int.tryParse('${json['doubanId'] ?? ''}'),
      episodes: (json['episodes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AggregatorEpisode.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      health: json['health'] is Map
          ? SourceHealthSnapshot.fromJson(
              Map<String, dynamic>.from(json['health'] as Map),
            )
          : null,
      tmdb: json['tmdb'] is Map
          ? TmdbEnrichment.fromJson(
              Map<String, dynamic>.from(json['tmdb'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'sourceName': sourceName,
    'remoteId': remoteId,
    'title': title,
    'year': year,
    'poster': poster,
    'category': category,
    'remarks': remarks,
    'desc': desc,
    'typeName': typeName,
    'doubanId': doubanId,
    'episodes': episodes.map((item) => item.toJson()).toList(),
    if (health != null) 'health': health!.toJson(),
    if (tmdb != null) 'tmdb': tmdb!.toJson(),
  };
}

class AggregatorMediaDetail {
  const AggregatorMediaDetail({
    required this.source,
    required this.sourceName,
    required this.remoteId,
    required this.title,
    this.year,
    this.poster,
    this.backdrop,
    this.desc,
    this.category,
    this.typeName,
    this.doubanId,
    this.episodes = const [],
    this.tmdb,
  });

  final String source;
  final String sourceName;
  final String remoteId;
  final String title;
  final String? year;
  final String? poster;
  final String? backdrop;
  final String? desc;
  final String? category;
  final String? typeName;
  final int? doubanId;
  final List<AggregatorEpisode> episodes;
  final TmdbEnrichment? tmdb;

  String get identity => '$source:$remoteId';
  String? get bestPoster =>
      tmdb?.posterUrl?.isNotEmpty == true ? tmdb!.posterUrl : poster;
  String? get bestBackdrop =>
      tmdb?.backdropUrl?.isNotEmpty == true ? tmdb!.backdropUrl : backdrop;

  AggregatorMediaDetail copyWith({
    List<AggregatorEpisode>? episodes,
    TmdbEnrichment? tmdb,
  }) {
    return AggregatorMediaDetail(
      source: source,
      sourceName: sourceName,
      remoteId: remoteId,
      title: title,
      year: year,
      poster: poster,
      backdrop: backdrop,
      desc: desc,
      category: category,
      typeName: typeName,
      doubanId: doubanId,
      episodes: episodes ?? this.episodes,
      tmdb: tmdb ?? this.tmdb,
    );
  }

  factory AggregatorMediaDetail.fromJson(Map<String, dynamic> json) {
    return AggregatorMediaDetail(
      source: (json['source'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '').toString(),
      remoteId: (json['remoteId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      year: json['year']?.toString(),
      poster: json['poster']?.toString(),
      backdrop: json['backdrop']?.toString(),
      desc: json['desc']?.toString(),
      category: json['category']?.toString(),
      typeName: json['typeName']?.toString(),
      doubanId: int.tryParse('${json['doubanId'] ?? ''}'),
      episodes: (json['episodes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AggregatorEpisode.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      tmdb: json['tmdb'] is Map
          ? TmdbEnrichment.fromJson(Map<String, dynamic>.from(json['tmdb']))
          : null,
    );
  }

  factory AggregatorMediaDetail.fromSearch(AggregatorSearchResult result) {
    return AggregatorMediaDetail(
      source: result.source,
      sourceName: result.sourceName,
      remoteId: result.remoteId,
      title: result.title,
      year: result.year,
      poster: result.poster,
      desc: result.desc,
      category: result.category,
      typeName: result.typeName,
      doubanId: result.doubanId,
      episodes: result.episodes,
      tmdb: result.tmdb,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'sourceName': sourceName,
    'remoteId': remoteId,
    'title': title,
    'year': year,
    'poster': poster,
    'backdrop': backdrop,
    'desc': desc,
    'category': category,
    'typeName': typeName,
    'doubanId': doubanId,
    'episodes': episodes.map((item) => item.toJson()).toList(),
    if (tmdb != null) 'tmdb': tmdb!.toJson(),
  };
}

class AggregatorPlaySession {
  const AggregatorPlaySession({
    required this.title,
    required this.source,
    required this.sourceName,
    required this.remoteId,
    required this.episodeIndex,
    required this.episodes,
    required this.playUrl,
    this.cover,
    this.headers = const {},
    this.resumePosition = Duration.zero,
  });

  final String title;
  final String source;
  final String sourceName;
  final String remoteId;
  final int episodeIndex;
  final List<AggregatorEpisode> episodes;
  final String playUrl;
  final String? cover;
  final Map<String, String> headers;
  final Duration resumePosition;
}

class ProviderSearchTrace {
  const ProviderSearchTrace({
    required this.source,
    required this.sourceName,
    required this.ok,
    required this.elapsedMs,
    this.resultCount = 0,
    this.error,
  });

  final String source;
  final String sourceName;
  final bool ok;
  final int elapsedMs;
  final int resultCount;
  final String? error;
}

class AggregatorSearchBatch {
  const AggregatorSearchBatch({
    required this.keyword,
    required this.results,
    required this.traces,
    required this.completedSources,
    required this.totalSources,
    required this.searching,
    this.fromCache = false,
  });

  final String keyword;
  final List<AggregatorSearchResult> results;
  final List<ProviderSearchTrace> traces;
  final int completedSources;
  final int totalSources;
  final bool searching;
  final bool fromCache;

  double get progress =>
      totalSources == 0 ? 0 : completedSources / totalSources.clamp(1, 9999);
}
