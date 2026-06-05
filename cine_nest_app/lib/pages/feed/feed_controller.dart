import 'package:get/get.dart';
import 'package:cine_nest/models/post.dart';
import 'package:cine_nest/http/feed_api.dart';

class FeedController extends GetxController {
  // 帖子列表
  var postList = <Post>[].obs;
  // 加载状态
  var isLoading = true.obs;
  // 分页页码
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  // 初始加载
  Future<void> loadData() async {
    try {
      isLoading(true);
      _page = 1;
      var data = await FeedApi.getAiRecommendations(page: _page);
      postList.assignAll(data);
    } catch (e) {
      Get.snackbar("错误", "获取推荐失败: $e");
    } finally {
      isLoading(false);
    }
  }

  // 下拉刷新/上拉加载更多
  Future<void> loadMore() async {
    _page++;
    var data = await FeedApi.getAiRecommendations(page: _page);
    postList.addAll(data);
  }
}
