import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';

class MovieDetailController extends GetxController {
  final int movieId = Get.arguments['movieId'];

  var isLoading = true.obs;
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
      }
    } catch (e) {
      Get.snackbar("错误", "获取详情失败: $e");
    } finally {
      isLoading(false);
    }
  }
}
