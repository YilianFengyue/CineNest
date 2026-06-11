import 'package:dio/dio.dart';

class TmdbMediaItem {
  final int id;
  final String title;
  final String originalTitle;
  final String posterPath;
  final String backdropPath;
  final String overview;
  final String releaseDate;
  final double voteAverage;
  final int voteCount;
  final String mediaType;
  final List<int> genreIds;

  const TmdbMediaItem({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.posterPath = '',
    this.backdropPath = '',
    this.overview = '',
    this.releaseDate = '',
    this.voteAverage = 0,
    this.voteCount = 0,
    this.mediaType = 'movie',
    this.genreIds = const [],
  });

  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
  String poster([String size = 'w500']) =>
      posterPath.isEmpty ? '' : '$_imageBase/$size$posterPath';
  String backdrop([String size = 'w780']) =>
      backdropPath.isEmpty ? '' : '$_imageBase/$size$backdropPath';

  static const _imageBase = 'https://image.tmdb.org/t/p';

  factory TmdbMediaItem.fromJson(Map<String, dynamic> json) {
    final isMovie = (json['media_type'] ?? json['_media_type'] ?? 'movie') != 'tv';
    return TmdbMediaItem(
      id: json['id'] ?? 0,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      originalTitle:
          (json['original_title'] ?? json['original_name'] ?? '').toString(),
      posterPath: (json['poster_path'] ?? '').toString(),
      backdropPath: (json['backdrop_path'] ?? '').toString(),
      overview: (json['overview'] ?? '').toString(),
      releaseDate:
          (json['release_date'] ?? json['first_air_date'] ?? '').toString(),
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: (json['vote_count'] ?? 0) as int,
      mediaType: isMovie ? 'movie' : 'tv',
      genreIds: (json['genre_ids'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
    );
  }
}

/// 演职员条目：cast（演员）时 [role] 是饰演角色名，crew（制作人员）时是职务。
class TmdbCredit {
  final int id;
  final String name;
  final String originalName;
  final String role;
  final String department;
  final String profilePath;

  const TmdbCredit({
    required this.id,
    required this.name,
    this.originalName = '',
    this.role = '',
    this.department = '',
    this.profilePath = '',
  });

  String profile([String size = 'w185']) =>
      profilePath.isEmpty ? '' : '${TmdbMediaItem._imageBase}/$size$profilePath';
}

/// 一部影片/剧集的演职员表。
class TmdbCredits {
  final List<TmdbCredit> cast;
  final List<TmdbCredit> crew;

  const TmdbCredits({this.cast = const [], this.crew = const []});
}

class TmdbDirectService {
  TmdbDirectService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
              queryParameters: {
                'api_key': _apiKey,
                'language': 'zh-CN',
              },
            ));

  final Dio _dio;

  static const _baseUrl = 'https://api.themoviedb.org/3';
  static const _apiKey = 'a0fa41814b4b2a71464c9fe605029796';

  Future<List<TmdbMediaItem>> trending({
    String mediaType = 'all',
    String timeWindow = 'week',
    int page = 1,
  }) async {
    final resp = await _dio.get('/trending/$mediaType/$timeWindow',
        queryParameters: {'page': page});
    return _parseList(resp.data);
  }

  Future<List<TmdbMediaItem>> discover({
    String mediaType = 'movie',
    int? genreId,
    int page = 1,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'sort_by': 'popularity.desc',
    };
    if (genreId != null) params['with_genres'] = genreId;
    final resp =
        await _dio.get('/discover/$mediaType', queryParameters: params);
    return _parseList(resp.data, fallbackType: mediaType);
  }

  Future<List<TmdbMediaItem>> popular({String mediaType = 'movie', int page = 1}) async {
    final resp = await _dio.get('/$mediaType/popular', queryParameters: {'page': page});
    return _parseList(resp.data, fallbackType: mediaType);
  }

  Future<List<TmdbMediaItem>> topRated({String mediaType = 'movie', int page = 1}) async {
    final resp = await _dio.get('/$mediaType/top_rated', queryParameters: {'page': page});
    return _parseList(resp.data, fallbackType: mediaType);
  }

  Future<List<TmdbMediaItem>> search(
    String query, {
    String mediaType = 'movie',
    String? year,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'query': query, 'page': page};
    if (year != null && year.isNotEmpty) params['year'] = year;
    final resp =
        await _dio.get('/search/$mediaType', queryParameters: params);
    return _parseList(resp.data, fallbackType: mediaType);
  }

  Future<TmdbMediaItem> detail(int id, {String mediaType = 'movie'}) async {
    final resp = await _dio.get('/$mediaType/$id');
    final json = Map<String, dynamic>.from(resp.data as Map);
    json['_media_type'] = mediaType;
    if (mediaType == 'movie') {
      json['genre_ids'] =
          (json['genres'] as List?)?.map((g) => g['id'] as int).toList() ?? [];
    } else {
      json['genre_ids'] =
          (json['genres'] as List?)?.map((g) => g['id'] as int).toList() ?? [];
    }
    return TmdbMediaItem.fromJson(json);
  }

  /// 演职员表。电影走 /credits；剧集走 /aggregate_credits（按整部剧聚合，
  /// cast 的角色在 roles 数组、crew 的职务在 jobs 数组里）。
  Future<TmdbCredits> credits(int id, {String mediaType = 'movie'}) async {
    final isTv = mediaType == 'tv';
    final resp = await _dio
        .get(isTv ? '/tv/$id/aggregate_credits' : '/movie/$id/credits');
    final data = resp.data as Map;

    TmdbCredit parse(Map raw, {required bool isCast}) {
      final json = Map<String, dynamic>.from(raw);
      String role;
      String department = '';
      if (isCast) {
        role = isTv
            ? ((json['roles'] as List?)?.isNotEmpty == true
                ? (json['roles'][0]['character'] ?? '').toString()
                : '')
            : (json['character'] ?? '').toString();
      } else {
        role = isTv
            ? ((json['jobs'] as List?)?.isNotEmpty == true
                ? (json['jobs'][0]['job'] ?? '').toString()
                : '')
            : (json['job'] ?? '').toString();
        department = (json['department'] ?? '').toString();
      }
      return TmdbCredit(
        id: json['id'] ?? 0,
        name: (json['name'] ?? '').toString(),
        originalName: (json['original_name'] ?? '').toString(),
        role: role,
        department: department,
        profilePath: (json['profile_path'] ?? '').toString(),
      );
    }

    return TmdbCredits(
      cast: ((data['cast'] as List?) ?? [])
          .map((e) => parse(e as Map, isCast: true))
          .toList(),
      crew: ((data['crew'] as List?) ?? [])
          .map((e) => parse(e as Map, isCast: false))
          .toList(),
    );
  }

  List<TmdbMediaItem> _parseList(dynamic data, {String? fallbackType}) {
    final results = (data as Map)['results'] as List? ?? [];
    return results.map((e) {
      final json = Map<String, dynamic>.from(e as Map);
      if (fallbackType != null && json['media_type'] == null) {
        json['_media_type'] = fallbackType;
      }
      return TmdbMediaItem.fromJson(json);
    }).toList();
  }
}
