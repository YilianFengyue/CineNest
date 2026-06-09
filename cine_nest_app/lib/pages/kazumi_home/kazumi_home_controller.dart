import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:get/get.dart';

class HomeCategory {
  final String label;
  final String type;
  final int? genreId;

  const HomeCategory(this.label, this.type, [this.genreId]);
}

const homeCategories = [
  HomeCategory('热门推荐', 'trending'),
  HomeCategory('热门电影', 'popular_movie'),
  HomeCategory('热门剧集', 'popular_tv'),
  HomeCategory('高分电影', 'top_movie'),
  HomeCategory('高分剧集', 'top_tv'),
  HomeCategory('动作', 'genre_movie', 28),
  HomeCategory('喜剧', 'genre_movie', 35),
  HomeCategory('科幻', 'genre_movie', 878),
  HomeCategory('动画', 'genre_movie', 16),
  HomeCategory('恐怖', 'genre_movie', 27),
  HomeCategory('爱情', 'genre_movie', 10749),
  HomeCategory('悬疑', 'genre_movie', 9648),
  HomeCategory('剧情', 'genre_movie', 18),
];

class KazumiHomeController extends GetxController {
  final TmdbDirectService _tmdb = TmdbDirectService();

  final trendingList = <TmdbMediaItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMsg = ''.obs;
  final currentCategory = homeCategories[0].obs;

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadTrending();
  }

  Future<void> switchCategory(HomeCategory cat) async {
    if (cat.type == currentCategory.value.type &&
        cat.genreId == currentCategory.value.genreId) {
      return;
    }
    currentCategory.value = cat;
    _page = 1;
    trendingList.clear();
    await loadTrending();
  }

  Future<void> loadTrending() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final items = await _fetch(page: 1);
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
      final items = await _fetch(page: _page);
      trendingList.addAll(items);
    } catch (_) {
      _page--;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<List<TmdbMediaItem>> _fetch({required int page}) async {
    final cat = currentCategory.value;
    switch (cat.type) {
      case 'trending':
        return _tmdb.trending(page: page);
      case 'popular_movie':
        return _tmdb.popular(mediaType: 'movie', page: page);
      case 'popular_tv':
        return _tmdb.popular(mediaType: 'tv', page: page);
      case 'top_movie':
        return _tmdb.topRated(mediaType: 'movie', page: page);
      case 'top_tv':
        return _tmdb.topRated(mediaType: 'tv', page: page);
      case 'genre_movie':
        return _tmdb.discover(
            mediaType: 'movie', genreId: cat.genreId!, page: page);
      default:
        return _tmdb.trending(page: page);
    }
  }
}
