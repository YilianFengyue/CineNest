import 'package:cine_nest/pages/creative/models/content_block.dart';

/// 富交互卡片的演示假数据（成员 C · 仅供预览画廊 / 设计走查）。
///
/// 图片用 picsum 占位（国内可达），真数据由后端按 `microdesign.v1.1` 下发。
/// 每项 = (区块说明, 区块)，画廊页按顺序渲染。
typedef GalleryItem = ({String label, ContentBlock block});

String _img(String seed, [int w = 300, int h = 420]) =>
    'https://picsum.photos/seed/$seed/$w/$h';

List<GalleryItem> cardGalleryMocks() => [
      (
        label: 'playableMovieCard · 可播放电影介绍卡',
        block: ContentBlock(ContentBlockType.playableMovieCard, {
          'cover': _img('interstellar'),
          'title': '星际穿越',
          'year': '2014',
          'rating': 9.4,
          'rating_label': '豆瓣',
          'genres': ['科幻', '冒险', '剧情'],
          'summary': '为寻找人类新家园，库珀穿越虫洞踏上星际之旅，在相对论的时间洪流里与女儿隔空相望。',
          'source_count': 5,
          'actions': [
            {'type': 'resolveAndPlay', 'label': '立即播放', 'data': {}},
            {'type': 'openPoster', 'label': '查看海报', 'data': {}},
          ],
        }),
      ),
      (
        label: 'movieCarousel · 电影海报轮播组',
        block: ContentBlock(ContentBlockType.movieCarousel, {
          'title': '为你精选',
          'items': [
            {'cover': _img('dune2'), 'title': '沙丘2', 'year': '2024', 'rating': 8.5, 'action': {'type': 'openPoster', 'data': {}}},
            {'cover': _img('oppenheimer'), 'title': '奥本海默', 'year': '2023', 'rating': 8.8, 'action': {'type': 'openPoster', 'data': {}}},
            {'cover': _img('blade'), 'title': '银翼杀手2049', 'year': '2017', 'rating': 8.4},
            {'cover': _img('arrival'), 'title': '降临', 'year': '2016', 'rating': 7.8},
            {'cover': _img('gravity'), 'title': '地心引力', 'year': '2013', 'rating': 7.9},
          ],
        }),
      ),
      (
        label: 'reviewQuoteCard · 影评引用卡',
        block: ContentBlock(ContentBlockType.reviewQuoteCard, {
          'quote': '诺兰把硬核物理拍出了宗教般的庄严，沙海与星海互为镜像，是近十年最浪漫的科幻。',
          'author': '木卫二',
          'source': '豆瓣影评',
          'rating': 9.0,
        }),
      ),
      (
        label: 'sourceTraceCard · 来源溯源卡',
        block: ContentBlock(ContentBlockType.sourceTraceCard, {
          'query': '星际穿越',
          'items': [
            {'key': 'douban', 'label': '豆瓣', 'count': 1, 'status': 'ok'},
            {'key': 'tmdb', 'label': 'TMDB', 'status': 'empty'},
            {'key': 'resource', 'label': '资源库', 'count': 5, 'status': 'ok'},
            {'key': 'bilibili', 'label': 'B 站', 'status': 'empty'},
          ],
        }),
      ),
      (
        label: 'newsCard · 资讯卡',
        block: ContentBlock(ContentBlockType.newsCard, {
          'title': '诺兰新作《奥德赛》首曝概念剧照，2026 暑期档定档',
          'source': '影视前线',
          'published_at': '2 小时前',
          'summary': '改编自荷马史诗，IMAX 胶片拍摄，延续非线性叙事，主演阵容堪称豪华。',
          'cover': _img('odyssey', 480, 270),
          'tags': ['诺兰', '史诗', 'IMAX'],
        }),
      ),
      (
        label: 'mediaGallery · 图集（横滑）',
        block: ContentBlock(ContentBlockType.mediaGallery, {
          'title': '剧照',
          'layout': 'swiper',
          'urls': [
            _img('still1'),
            _img('still2'),
            _img('still3'),
            _img('still4'),
            _img('still5'),
          ],
        }),
      ),
      (
        label: 'mediaGallery · 图集（网格）',
        block: ContentBlock(ContentBlockType.mediaGallery, {
          'layout': 'grid',
          'urls': [
            _img('g1'),
            _img('g2'),
            _img('g3'),
            _img('g4'),
            _img('g5'),
            _img('g6'),
          ],
        }),
      ),
      (
        label: 'videoExplainCard · 视频解说卡',
        block: ContentBlock(ContentBlockType.videoExplainCard, {
          'title': '【深度解说】诺兰为什么选择《奥德赛》？看完这条就懂了',
          'cover': _img('explain', 480, 270),
          'up': '影视飓风',
          'duration': '12:36',
          'play_count': '48.2 万',
        }),
      ),
    ];
