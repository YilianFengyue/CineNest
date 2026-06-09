import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:get/get.dart';

class KazumiHomeController extends GetxController {
  final TmdbDirectService _tmdb = TmdbDirectService();

  final trendingList = <TmdbMediaItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMsg = ''.obs;

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadTrending();
  }

  Future<void> loadTrending() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final items = await _tmdb.trending();
      trendingList.assignAll(items);
      _page = 1;
    } catch (e) {
      errorMsg.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value) return;
    isLoadingMore.value = true;
    try {
      _page++;
      final items = await _tmdb.popular(page: _page);
      trendingList.addAll(items);
    } catch (_) {
      _page--;
    } finally {
      isLoadingMore.value = false;
    }
  }
}
