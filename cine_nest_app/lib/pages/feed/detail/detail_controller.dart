import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';
import 'package:flutter/foundation.dart';

class MovieDetailController extends GetxController {
  final int movieId = Get.arguments['movieId'];

  var isLoading = true.obs;
  var isFavorited = false.obs;
  var isFavoriting = false.obs;
  var movie = Rxn<Movie>();

  @override
  void onInit() {
    super.onInit();
    fetchMovieDetail();
  }

  Future<void> fetchMovieDetail() async {
    try {
      isLoading(true);
      final response = await Request().get(ApiConstants.movieDetail(movieId));
      if (response.data != null) {
        movie.value = Movie.fromJson(response.data);
        // 从响应中同步收藏状态
        isFavorited.value = movie.value!.isCollected;
      }
    } catch (e) {
      debugPrint("获取详情失败: $e");
    } finally {
      isLoading(false);
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
