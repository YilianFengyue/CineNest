import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/models/post.dart';
import 'package:cine_nest/models/scenario_response.dart';

class FeedApi {
  const FeedApi._();

  static Future<ScenarioResponse> getScenarioRecommendations({
    required String scenario,
  }) async {
    final response = await Request().get(
      '/api/feed/scenario',
      queryParameters: {'scenario': scenario},
    );
    return ScenarioResponse.fromJson(Map<String, dynamic>.from(response.data));
  }

  static Future<List<Post>> getAiRecommendations({
    int page = 1,
    String? scenario,
  }) async {
    final feedResponse = await Request().get(
      ApiConstants.feed,
      queryParameters: {
        'page': page,
        'refresh': true,
        'scenario': scenario,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final feedPosts = _parsePosts(feedResponse.data);
    if (feedResponse.statusCode == 200 && feedPosts.isNotEmpty) {
      return feedPosts;
    }

    final discoveryResponse = await Request().get(
      ApiConstants.discovery,
      queryParameters: {'page': page},
    );
    return _parseMovies(discoveryResponse.data)
        .map(
          (movie) => Post(
            movie: movie,
            recommendReason: 'Fallback discovery recommendation',
            hasVideoSource: true,
            hasBilibili: true,
          ),
        )
        .toList();
  }

  static List<Post> _parsePosts(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<Movie> _parseMovies(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
