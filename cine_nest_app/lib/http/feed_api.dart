import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/models/post.dart';

class FeedApi {
  /// 获取 AI 推荐帖子流
  static Future<List<Post>> getAiRecommendations({int page = 1}) async {
    try {
      // 对应后端 routers/feed.py 中的路径：@router.get("/feed") 且 prefix="/api"
      // 后端返回的是直接的 List[Post]，没有 code/data 包装
      final response = await Request().get(ApiConstants.feed, queryParameters: {
        'refresh': page == 1,
        'mode': 'popular',
      });

      if (response.data is List) {
        List data = response.data;
        return data.map((json) => Post.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}