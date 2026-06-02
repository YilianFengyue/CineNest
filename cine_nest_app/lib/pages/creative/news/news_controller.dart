import 'package:cine_nest/pages/creative/models/bangumi_subject.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/models/news_item.dart';
import 'package:cine_nest/pages/creative/services/bangumi_service.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:get/get.dart';

/// 资讯 Tab 控制器（F12）。
///
/// 数据源：实时拉取 Bangumi 趋势条目（真实海报+评分），转成 [NewsItem] 的
/// 区块拼贴。网络失败时回退本地假数据，保证页面不空白。
///
/// 长期联调时，电影元数据应改走成员 B 的 `/api/movie`；Bangumi 作为
/// 自测临时源 / 番剧方向补充。
class NewsController extends GetxController {
  /// 首次加载中（用于决定是否显示骨架屏）。
  final RxBool loading = true.obs;
  final RxList<NewsItem> items = <NewsItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshNews();
  }

  Future<void> refreshNews() async {
    if (items.isEmpty) loading.value = true;
    final data = await _fetch();
    items.value = data;
    loading.value = false;
  }

  /// 拉取真实 Bangumi 趋势条目并转成区块卡；失败回退假数据。
  Future<List<NewsItem>> _fetch() async {
    try {
      final subjects = await BangumiService.instance.trending(limit: 12);
      final news = subjects.map(_toNewsItem).toList();
      logger.i('Bangumi 资讯加载成功：${news.length} 条');
      if (news.isNotEmpty) return news;
    } catch (e, st) {
      // 网络失败：回退本地假数据，保证页面不空白
      logger.e('Bangumi 资讯加载失败，回退假数据', error: e, stackTrace: st);
    }
    return _mockNews;
  }

  /// 一个 Bangumi 条目 → 一张资讯卡（标题 + 海报条区块）。
  NewsItem _toNewsItem(BangumiSubject s) => NewsItem(
    id: s.id.toString(),
    title: s.displayTitle,
    source: 'Bangumi 番组计划',
    publishedAt: _yearOf(s.info),
    blocks: [
      ContentBlock.posterRow(
        cover: s.cover,
        score: s.score,
        // v0 search 自带 summary 真实简介，没有则退回制作信息串
        summary: _cleanInfo(s.summary.isNotEmpty ? s.summary : s.info),
        tags: _tagsOf(s),
      ),
    ],
  );

  /// 清洗 Bangumi 的 info 串（去换行/全角空格、压缩空白、截断）。
  static String _cleanInfo(String s, [int max = 80]) {
    final t = s.replaceAll(RegExp(r'[\r\n　\s]+'), ' ').trim();
    if (t.isEmpty) return '';
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  static List<String> _tagsOf(BangumiSubject s) {
    final tags = <String>[];
    switch (s.type) {
      case 1:
        tags.add('书籍');
      case 2:
        tags.add('动画');
      case 4:
        tags.add('游戏');
      case 6:
        tags.add('影视');
    }
    if (s.rank > 0) tags.add('No.${s.rank}');
    return tags;
  }

  static String _yearOf(String info) =>
      RegExp(r'(\d{4})年').firstMatch(info)?.group(1) ?? '';

  // picsum 稳定占位图，演示用。真数据时换成 TMDB / B站封面。
  static String _img(String seed, int w, int h) =>
      'https://picsum.photos/seed/$seed/$w/$h';

  static final List<NewsItem> _mockNews = [
    NewsItem(
      id: 'n1',
      title: '诺兰新作《奥德赛》首曝概念剧照，2026 年暑期档定档',
      source: '影视前线',
      publishedAt: '2 小时前',
      blocks: [
        ContentBlock.text(
          '克里斯托弗·诺兰确认下一部作品改编自荷马史诗《奥德赛》，以 IMAX 胶片拍摄，'
          '据悉将延续其一贯的非线性叙事，主演阵容堪称豪华。',
        ),
        ContentBlock.tags(['史诗', '冒险', '诺兰', 'IMAX']),
        ContentBlock.images([
          _img('odyssey1', 300, 400),
          _img('odyssey2', 300, 400),
          _img('odyssey3', 300, 400),
          _img('odyssey4', 300, 400),
        ]),
        ContentBlock.video(
          title: '【深度解说】诺兰为什么选择《奥德赛》？看完这条就懂了',
          cover: _img('odysseyv', 320, 180),
          playCount: '48.2 万',
          duration: '12:36',
        ),
      ],
    ),
    NewsItem(
      id: 'n2',
      title: '吉卜力工作室公布全新原创动画，宫崎骏担任企划',
      source: '动画资讯站',
      publishedAt: '5 小时前',
      blocks: [
        ContentBlock.text(
          '继《你想活出怎样的人生》之后，吉卜力宣布启动新作企划，'
          '宫崎骏以企划身份参与，画面延续手绘质感。',
        ),
        ContentBlock.images([
          _img('ghibli1', 300, 400),
          _img('ghibli2', 300, 400),
          _img('ghibli3', 300, 400),
        ]),
        ContentBlock.tags(['动画', '吉卜力', '宫崎骏', '治愈']),
      ],
    ),
    NewsItem(
      id: 'n3',
      title: '《沙丘：第二部》登陆流媒体，4K HDR 版本同步上线',
      source: '流媒观察',
      publishedAt: '昨天',
      blocks: [
        ContentBlock.video(
          title: '《沙丘2》4K 片段抢先看：保罗骑乘沙虫名场面',
          cover: _img('dune', 320, 180),
          playCount: '126 万',
          duration: '03:48',
        ),
        ContentBlock.text(
          '维伦纽瓦执导的科幻巨制第二部正式上线流媒体，视听规格拉满，'
          '原声配乐由汉斯·季默操刀。',
        ),
        ContentBlock.rating(8.5, label: 'TMDB 评分'),
        ContentBlock.tags(['科幻', '史诗', '维伦纽瓦']),
      ],
    ),
    NewsItem(
      id: 'n4',
      title: '第 97 届奥斯卡提名揭晓，最佳影片竞争激烈',
      source: '颁奖季观察',
      publishedAt: '昨天',
      blocks: [
        ContentBlock.heading('最佳影片提名亮点'),
        ContentBlock.text(
          '本届提名呈现类型多元化趋势，独立制作与商业大片同台竞技，'
          '亚洲影人表现亮眼。',
        ),
        ContentBlock.tags(['奥斯卡', '颁奖季', '剧情', '提名']),
        ContentBlock.rating(9.1, label: '媒体场刊均分'),
      ],
    ),
    NewsItem(
      id: 'n5',
      title: 'B 站影视区热议：这部冷门佳作凭解说翻红',
      source: 'UP 主热榜',
      publishedAt: '2 天前',
      blocks: [
        ContentBlock.video(
          title: '【1080P】被严重低估的神作，全程无尿点高能解说',
          cover: _img('cult', 320, 180),
          playCount: '215 万',
          duration: '18:22',
        ),
        ContentBlock.text('一条深度解说视频带火一部冷门电影，弹幕区一致好评。'),
        ContentBlock.tags(['解说', '悬疑', '高分', 'B 站']),
      ],
    ),
    NewsItem(
      id: 'n6',
      title: 'A24 新恐怖片释出首支预告，氛围感拉满',
      source: '恐怖片研究所',
      publishedAt: '3 天前',
      blocks: [
        ContentBlock.images([
          _img('a24a', 300, 400),
          _img('a24b', 300, 400),
          _img('a24c', 300, 400),
          _img('a24d', 300, 400),
        ]),
        ContentBlock.text('A24 延续作者恐怖路线，预告以极简配乐与诡谲构图营造压迫感。'),
        ContentBlock.tags(['恐怖', 'A24', '氛围', '作者电影']),
      ],
    ),
  ];
}
