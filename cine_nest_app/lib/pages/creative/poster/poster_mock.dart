/// F8 互动海报演示假数据（成员 C）。
///
/// 结构对齐后端 `PosterSpec`（`microdesign.v1`/`v1.1`）：`{title, subtitle, style, blocks[], actions[]}`，
/// 因此 [PosterController] 的解析逻辑 mock 与真后端通用，后端就绪后直接换数据源。
library;

String _img(String seed, [int w = 300, int h = 420]) =>
    'https://picsum.photos/seed/$seed/$w/$h';

Map<String, dynamic> posterMockSpec() => {
      'schema_version': 'microdesign.v1.1',
      'id': 'mock:interstellar',
      'style': 'neon',
      'title': '星际穿越',
      'subtitle': 'Interstellar · 2014 · 科幻',
      'recommend_reason': '诺兰用相对论写就的太空史诗，把硬核物理拍出宗教般的庄严与父女深情。',
      'blocks': [
        {
          'type': 'banner',
          'data': {
            'image': _img('interstellar-bd', 800, 450),
            'poster': _img('interstellar-p', 300, 440),
            'title': '星际穿越',
            'subtitle': 'Interstellar · 2014',
            'style': 'neon',
          },
        },
        {
          'type': 'rating',
          'data': {'score': 9.4, 'label': '豆瓣'},
        },
        {
          'type': 'tagRow',
          'data': {
            'tags': ['科幻', '冒险', '剧情', '诺兰', 'IMAX'],
          },
        },
        {
          'type': 'heading',
          'data': {'text': '推荐理由'},
        },
        {
          'type': 'text',
          'data': {
            'text': '当地球濒临枯萎，库珀带着对女儿的承诺穿越虫洞。诺兰把宏大的宇宙尺度与私密的亲情并置，'
                '汉斯·季默的管风琴轰鸣里，时间成了最残忍也最温柔的角色。',
          },
        },
        {
          'type': 'heading',
          'data': {'text': '剧照'},
        },
        {
          'type': 'mediaGallery',
          'data': {
            'layout': 'swiper',
            'urls': [
              _img('still-1', 320, 200),
              _img('still-2', 320, 200),
              _img('still-3', 320, 200),
              _img('still-4', 320, 200),
              _img('still-5', 320, 200),
            ],
          },
        },
        {
          'type': 'reviewQuoteCard',
          'data': {
            'quote': '它让我重新相信，科幻可以同时是科学的、哲学的和催泪的。',
            'author': '木卫二',
            'source': '豆瓣影评',
            'rating': 9.0,
          },
        },
        {
          'type': 'heading',
          'data': {'text': '影人解说'},
        },
        {
          'type': 'videoExplainCard',
          'data': {
            'title': '【深度解说】星际穿越里的物理学，到底有多硬核？',
            'cover': _img('explain', 480, 270),
            'up': '影视飓风',
            'duration': '14:22',
            'play_count': '126 万',
          },
        },
        {
          'type': 'heading',
          'data': {'text': '可用线路'},
        },
        {
          'type': 'videoBar',
          'data': {
            'title': 'wjm3u8 · 1080P 中字',
            'cover': _img('line-1', 320, 200),
            'episode_count': 1,
          },
          'action': {
            'type': 'resolveAndPlay',
            'label': '立即播放',
            'data': {'provider_id': 'wujin', 'remote_id': '89203', 'line_name': 'wjm3u8'},
          },
        },
        {
          'type': 'videoBar',
          'data': {
            'title': '量子线路 · 4K HDR',
            'cover': _img('line-2', 320, 200),
            'episode_count': 1,
          },
          'action': {
            'type': 'resolveAndPlay',
            'label': '立即播放',
            'data': {'provider_id': 'liangzi', 'remote_id': '551', 'line_name': '4k'},
          },
        },
        {
          'type': 'sourceTraceCard',
          'data': {
            'query': '星际穿越',
            'items': [
              {'key': 'douban', 'label': '豆瓣', 'count': 1, 'status': 'ok'},
              {'key': 'tmdb', 'label': 'TMDB', 'count': 1, 'status': 'ok'},
              {'key': 'resource', 'label': '资源库', 'count': 5, 'status': 'ok'},
              {'key': 'bilibili', 'label': 'B 站', 'status': 'empty'},
            ],
          },
        },
      ],
      'actions': [
        {
          'type': 'resolveAndPlay',
          'label': '立即播放',
          'data': {'provider_id': 'wujin', 'remote_id': '89203'},
        },
      ],
    };
