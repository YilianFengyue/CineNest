import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/models/movie_graph.dart';
import 'package:flutter/foundation.dart';

class MovieDetailController extends GetxController {
  final int movieId = Get.arguments['movieId'];

  var isLoading = true.obs;
  var isFavorited = false.obs;
  var isFavoriting = false.obs;
  var movie = Rxn<Movie>();
  var movieGraph = Rxn<MovieGraphResponse>();

  @override
  void onInit() {
    super.onInit();
    debugPrint(">>> [MovieDetail] Controller initialized for movie: $movieId");
    fetchMovieDetail();
    fetchMovieGraph();
  }

  Future<void> fetchMovieDetail() async {
    try {
      isLoading(true);
      debugPrint(">>> [MovieDetail] Fetching detail from backend...");
      final response = await Request().get(ApiConstants.movieDetail(movieId));
      if (response.data != null && response.statusCode == 200) {
        movie.value = Movie.fromJson(response.data);
        isFavorited.value = movie.value!.isCollected;
        debugPrint(">>> [MovieDetail] Detail loaded: ${movie.value?.title}");
      } else {
        debugPrint(">>> [MovieDetail] Backend detail fetch failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint(">>> [MovieDetail] Error fetching detail: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchMovieGraph() async {
    try {
      debugPrint(">>> [MovieGraph] Attempting to fetch graph: /api/movie/$movieId/graph");
      final response = await Request().get("/api/movie/$movieId/graph");
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('nodes')) {
          movieGraph.value = MovieGraphResponse.fromJson(data);
          debugPrint(">>> [MovieGraph] Success: ${movieGraph.value?.nodes.length} nodes");
        } else {
          debugPrint(">>> [MovieGraph] Data format error: $data");
        }
      } else {
        debugPrint(">>> [MovieGraph] Request failed: ${response.statusCode} - ${response.data}");
      }
    } catch (e, stack) {
      debugPrint(">>> [MovieGraph] Exception: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> toggleFavorite() async {
    if (movie.value == null) return;
    try {
      isFavoriting(true);
      // 按照后端契约：POST /api/collections/toggle
      // 提交对象：{"movie_id": int, "title": "string", "poster_url": "string"}
      final response = await Request().post(
        '/api/collections/toggle',
        data: {
          'movie_id': movie.value!.id,
          'title': movie.value!.title,
          'poster_url': movie.value!.posterUrl,
        },
      );
      if (response.statusCode == 200) {
        // 后端返回成功，切换本地显示状态
        isFavorited.value = !isFavorited.value;
        Get.snackbar(
          "提示", 
          isFavorited.value ? "已添加到收藏" : "已取消收藏",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      debugPrint("切换收藏失败: $e");
      Get.snackbar("错误", "操作失败，请检查网络");
    } finally {
      isFavoriting(false);
    }
  }
}
