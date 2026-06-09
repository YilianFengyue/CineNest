# Bilibili Companion

CineNest 的 B站能力分成两条线：

- 播放页/详情页直接调用 `/api/bili/*`，返回 B站 raw 字段，Flutter 直接渲染列表并跳转 B站 App。
- Chat/Agent 调用 Bili Tools，拿轻量摘要做筛选、解释和卡片 attachment。

## Raw-first API

页面接口保留 B站原始字段，不把 `title`、`pic`、`arcurl`、`play`、`video_review` 等字段改名。

每条视频会追加一个非侵入字段 `_cinenest`：

```json
{
  "title": "用万字解读<em class=\"keyword\">电影</em>《<em class=\"keyword\">你的名字</em>》",
  "pic": "//i2.hdslb.com/bfs/archive/demo.jpg",
  "bvid": "BV1ysCCBTEVC",
  "_cinenest": {
    "title_plain": "用万字解读电影《你的名字》",
    "cover_url": "https://i2.hdslb.com/bfs/archive/demo.jpg",
    "web_url": "https://www.bilibili.com/video/BV1ysCCBTEVC",
    "app_url": "bilibili://video/BV1ysCCBTEVC",
    "fallback_url": "https://www.bilibili.com/video/BV1ysCCBTEVC",
    "duration_seconds": 1334,
    "pubdate_text": "2025-11-15",
    "score": 53208
  }
}
```

Flutter 优先用 `_cinenest.app_url` 拉起 B站 App，失败再用 `_cinenest.fallback_url`。

## Endpoints

```text
GET /api/bili/videos/search?keyword=你的名字&page=1&page_size=12
GET /api/bili/movie/videos?movie=你的名字&year=2016&page=1&page_size=12
GET /api/bili/video/{bvid}
GET /api/bili/video/{bvid}/related

GET /api/bili/articles/search?keyword=你的名字 影评
GET /api/bili/article/{cvid}/markdown

GET /api/bili/up/search?keyword=电影解说
GET /api/bili/up/{mid}
GET /api/bili/up/{mid}/videos

GET /api/bili/rank?type=cinephile
GET /api/bili/hot?page=1&page_size=12
GET /api/bili/hot/weekly
GET /api/bili/hot/weekly?week=250
```

分页统一为 `page` 和 `page_size`，`page_size` 最大 20。

## Response Envelope

```json
{
  "schema_version": "bili.raw.v1",
  "source": "bilibili",
  "result_type": "video",
  "movie": "你的名字",
  "page": 1,
  "page_size": 12,
  "count": 12,
  "query_used": ["你的名字 电影解说", "你的名字 影评"],
  "data": [],
  "extra": {
    "cached": false,
    "has_more": true,
    "total_candidates": 42
  }
}
```

`data` 是前端主消费字段，保持 B站 raw shape。

## Agent Tools

已注册：

```text
search_bili_movie_videos
search_bili_articles
get_bili_article_markdown
search_bili_up_users
build_bili_companion
```

`build_bili_companion` 会生成 Chat 可挂载的 `bilibili_companion` attachment，内容是轻量视频列表，不把完整 raw JSON 塞给 LLM。

Agent 规则：

- 问 B站解说、影评、混剪、UP 主、专栏时调用 Bili Tool。
- 不编造 B站视频标题、播放量、UP 主或专栏内容。
- B站视频只返回外链/App 跳转，不作为 CineNest 内置播放源。

## Runtime Notes

依赖：

```text
bilibili-api-python
curl_cffi
beautifulsoup4
```

后端使用 `curl_cffi` client，并限制并发。搜索缓存 30 分钟，电影聚合缓存 6 小时，详情缓存 12 小时。依赖缺失时 `/api/bili/*` 返回 503，不影响其他后端模块启动。
