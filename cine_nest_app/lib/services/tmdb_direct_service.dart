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
  }) async {
    final resp = await _dio.get('/trending/$mediaType/$timeWindow');
    return _parseList(resp.data);
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
