// CineNest 基建冒烟测试。
//
// 注：完整启动 MyApp 依赖 Hive/GetX 初始化（在 main() 中完成），单元测试中不便直接 pump。
// 这里只对纯逻辑基建做最小验证，UI 测试由各模块 Owner 自行补充。

import 'package:flutter_test/flutter_test.dart';

import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/models/post.dart';

void main() {
  test('Movie JSON 往返序列化', () {
    final movie = Movie(
      id: 550,
      title: '搏击俱乐部',
      genres: const ['剧情'],
      rating: 8.4,
    );
    final back = Movie.fromJson(movie.toJson());
    expect(back.id, 550);
    expect(back.title, '搏击俱乐部');
    expect(back.genres, const ['剧情']);
    expect(back.rating, 8.4);
  });

  test('Post 解析嵌套 Movie 与可看性标识', () {
    final post = Post.fromJson({
      'movie': {'id': 1, 'title': '示例'},
      'recommend_reason': '好看',
      'has_video_source': true,
      'has_bilibili': false,
    });
    expect(post.movie.id, 1);
    expect(post.recommendReason, '好看');
    expect(post.hasVideoSource, true);
    expect(post.hasBilibili, false);
  });
}
