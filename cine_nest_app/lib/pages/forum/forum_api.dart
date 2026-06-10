import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/forum.dart';

class ForumApi {
  const ForumApi();

  Future<ForumPostList> listPosts({
    required String clientId,
    int page = 1,
    int pageSize = 20,
    String sort = 'latest',
    String keyword = '',
  }) async {
    final response = await Request().get(
      ApiConstants.forumPosts,
      queryParameters: {
        'client_id': clientId,
        'page': page,
        'page_size': pageSize,
        'sort': sort,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    );
    _ensureOk(response.statusCode, response.data);
    return ForumPostList.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<ForumPostDetailResponse> getPost(String id, String clientId) async {
    final response = await Request().get(
      ApiConstants.forumPost(id),
      queryParameters: {'client_id': clientId},
    );
    _ensureOk(response.statusCode, response.data);
    return ForumPostDetailResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> createPost({
    required String title,
    required String content,
    required String authorName,
    required String clientId,
  }) async {
    final response = await Request().post(
      ApiConstants.forumPosts,
      data: {
        'title': title,
        'content': content,
        'author_name': authorName,
        'client_id': clientId,
      },
    );
    _ensureOk(response.statusCode, response.data);
  }

  Future<Map<String, dynamic>> toggleLike(String postId, String clientId) async {
    final response = await Request().post(
      ApiConstants.forumPostLike(postId),
      data: {'client_id': clientId},
    );
    _ensureOk(response.statusCode, response.data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ForumComment> createComment({
    required String postId,
    required String content,
    required String authorName,
    required String clientId,
  }) async {
    final response = await Request().post(
      ApiConstants.forumPostComments(postId),
      data: {
        'content': content,
        'author_name': authorName,
        'client_id': clientId,
      },
    );
    _ensureOk(response.statusCode, response.data);
    return ForumComment.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  void _ensureOk(int? statusCode, Object? data) {
    if (statusCode != 200) {
      final message = data is Map
          ? (data['detail'] ?? data['message'] ?? data).toString()
          : data.toString();
      throw Exception(message);
    }
  }
}
