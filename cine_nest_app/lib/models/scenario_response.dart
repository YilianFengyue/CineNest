import 'package:cine_nest/models/post.dart';

class ScenarioResponse {
  final List<Post> posts;
  final String? debugInfo;

  ScenarioResponse({
    required this.posts,
    this.debugInfo,
  });

  factory ScenarioResponse.fromJson(Map<String, dynamic> json) {
    return ScenarioResponse(
      posts: (json['posts'] as List?)
              ?.map((e) => Post.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      debugInfo: json['debug_info'] as String?,
    );
  }
}
