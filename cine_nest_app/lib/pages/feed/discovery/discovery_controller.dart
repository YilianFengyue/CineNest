import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';

class DiscoveryController extends GetxController {
  var isLoading = true.obs;
  var movieList = <Movie>[].obs;
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    try {
      isLoading(true);
      _page = 1;
      final response = await Request().get(ApiConstants.discovery, queryParameters: {'page': _page});
      if (response.data is List) {
        List data = response.data;
        movieList.assignAll(data.map((json) => Movie.fromJson(json)).toList());
      }
    } finally {
      isLoading(false);
    }
  }

  Future<void> loadMore() async {
    try {
      _page++;
      final response = await Request().get(ApiConstants.discovery, queryParameters: {'page': _page});
      if (response.data is List) {
        List data = response.data;
        movieList.addAll(data.map((json) => Movie.fromJson(json)).toList());
      }
    } catch (e) {
      _page--;
    }
  }
}
