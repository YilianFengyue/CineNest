import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/news/news_controller.dart';

/// 资讯 mock 假数据（成员 C · F12）。
///
/// 用途：后端 `/api/news` 拉不到 / 返回空时兜底，保证资讯列表永远有内容，
/// 方便调列表流畅性、收藏、点击进海报（走 mock spec）。真 seed 数据就位后由真接口替换。
///
/// 每条都带 `openPoster` 动作（data 留空 → 海报页走 [posterMockSpec]），
/// 封面故意混入"有图 / 无图"两种，验证 [CoverImage] 的占位图兜底。

/// 一条资讯卡（newsCard + 可选图集），openPoster 留空走 mock 海报。
ContentBlock _newsCard({
  required String id,
  required String title,
  required String source,
  required String publishedAt,
  required String summary,
  String cover = '',
  List<String> tags = const [],
}) {
  return ContentBlock(
    ContentBlockType.newsCard,
    {
      'title': title,
      'source': source,
      'published_at': publishedAt,
      'summary': summary,
      'cover': cover,
      'tags': tags,
    },
    const MicroAction(type: 'openPoster', label: '查看互动海报', data: {}),
  );
}

ContentBlock _gallery(
  List<String> urls, {
  String layout = 'swiper',
  String title = '相关剧照',
}) {
  return ContentBlock(ContentBlockType.mediaGallery, {
    'title': title,
    'layout': layout,
    'urls': urls,
  });
}

/// picsum 稳定取图（同 seed 同图，便于反复看同一套 UI）。
String _pic(String seed, {int w = 800, int h = 450}) =>
    'https://picsum.photos/seed/${Uri.encodeComponent(seed)}/$w/$h';

/// 一批 mock 资讯。
List<NewsEntry> mockNewsEntries() {
  return [
    NewsEntry(
      id: 'mock-news-1',
      title: '《沙丘 3》定档：维伦纽瓦回归执导',
      blocks: [
        _newsCard(
          id: 'mock-news-1',
          title: '《沙丘 3》定档：维伦纽瓦回归执导',
          source: 'CineNest 资讯',
          publishedAt: '1 小时前',
          summary: '传奇影业宣布《沙丘》系列第三部正式立项，预计聚焦《沙丘救世主》故事线，'
              '甜茶与赞达亚confirmed回归。',
          cover: _pic('dune3'),
          tags: ['科幻', '续作', '2026'],
        ),
        _gallery([_pic('dune3-a'), _pic('dune3-b'), _pic('dune3-c')]),
      ],
    ),
    NewsEntry(
      id: 'mock-news-2',
      title: '诺兰新作《奥德赛》首支预告释出',
      blocks: [
        _newsCard(
          id: 'mock-news-2',
          title: '诺兰新作《奥德赛》首支预告释出',
          source: '影视前线',
          publishedAt: '3 小时前',
          summary: '克里斯托弗·诺兰执导的史诗巨制《奥德赛》放出先导预告，'
              '马特·达蒙、汤姆·赫兰德、赞达亚领衔，IMAX 全程拍摄。',
          cover: _pic('odyssey'),
          tags: ['史诗', '诺兰', 'IMAX'],
        ),
      ],
    ),
    NewsEntry(
      id: 'mock-news-3',
      title: '本周高分新片盘点：三部口碑爆款',
      blocks: [
        _newsCard(
          id: 'mock-news-3',
          title: '本周高分新片盘点：三部口碑爆款',
          source: 'CineNest 编辑部',
          publishedAt: '今天',
          summary: '本周院线与流媒体上新里，有三部作品评分突破 8.5，涵盖悬疑、动画与文艺片。',
          // 故意不给 cover，验证占位图兜底。
          tags: ['盘点', '高分'],
        ),
        _gallery(
          [_pic('week-1'), _pic('week-2'), _pic('week-3'), _pic('week-4')],
          layout: 'grid',
          title: '本周片单',
        ),
      ],
    ),
    NewsEntry(
      id: 'mock-news-4',
      title: '宫崎骏《你想活出怎样的人生》重映',
      blocks: [
        _newsCard(
          id: 'mock-news-4',
          title: '宫崎骏《你想活出怎样的人生》重映',
          source: '动画资讯',
          publishedAt: '昨天',
          summary: '吉卜力工作室宣布该片以 4K 修复版重新上映，新增 12 分钟未公开分镜特辑。',
          cover: _pic('ghibli'),
          tags: ['动画', '吉卜力', '重映'],
        ),
      ],
    ),
    NewsEntry(
      id: 'mock-news-5',
      title: '《奥本海默》导演剪辑版蓝光发布',
      blocks: [
        _newsCard(
          id: 'mock-news-5',
          title: '《奥本海默》导演剪辑版蓝光发布',
          source: '收藏频道',
          publishedAt: '2 天前',
          summary: '附带超过 3 小时幕后纪录片与黑白胶片花絮，被影迷称为年度最值得收藏的实体版本。',
          cover: _pic('oppenheimer'),
          tags: ['传记', '蓝光'],
        ),
        _gallery([_pic('oppen-a'), _pic('oppen-b')]),
      ],
    ),
    NewsEntry(
      id: 'mock-news-6',
      title: '柏林电影节金熊奖揭晓',
      blocks: [
        _newsCard(
          id: 'mock-news-6',
          title: '柏林电影节金熊奖揭晓',
          source: '国际影讯',
          publishedAt: '3 天前',
          summary: '一部聚焦移民家庭的现实主义作品摘得最佳影片，评审团盛赞其"克制而有力"。',
          // 无 cover，占位图兜底。
          tags: ['电影节', '获奖'],
        ),
      ],
    ),
  ];
}
