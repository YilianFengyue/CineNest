import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';

class MovieDetailController extends GetxController {
  final int movieId = Get.arguments['movieId'];

  var isLoading = true.obs;
  var isFavorited = false.obs;
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
        // 从后端返回的 movie 详情中读取收藏状态
        isFavorited.value = response.data['is_favorited'] ?? false;
      }
    } catch (e) {
      Get.snackbar("错误", "获取详情失败: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> toggleFavorite() async {
    if (movie.value == null) return;
    try {
      final response = await Request().post(
        '/api/movie/${movie.value!.id}/favorite',
        data: movie.value!.toJson(),
      );
      if (response.statusCode == 200) {
        isFavorited.value = response.data['is_favorited'] ?? !isFavorited.value;
        Get.snackbar("提示", isFavorited.value ? "已收藏" : "已取消收藏",
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
      }
    } catch (e) {
      Get.snackbar("错误", "操作失败: $e");
    }
  }
}
