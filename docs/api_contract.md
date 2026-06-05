# API 接口契约（Day 1 共建，前后端共同遵守）

> 任何字段改动需三人同步，并同时改 Flutter `lib/models/` 与后端 `models/schemas.py`。
> Base URL 由手机端设置页配置（PC 的 `http://IP:Port`）。
> 后端 Agent / MicroDesign / 播放资源当前详细契约见
> [docs/modules/backend_agent.md](modules/backend_agent.md)。本文保留共建总览和跨组接口入口。

## 当前后端版本

| 项 | 值 |
|---|---|
| 后端版本 | `1.2.0` |
| MicroDesign | `microdesign.v1.1` |
| 资源站 | 24 个注册 Provider，其中 20 个 MacCMS 默认启用 |
| Agent | REST + WebSocket，支持模型选择、SQLite 记忆、结构化附件 |

## v1.2 新增接口总览

### Agent / Chat

| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/agent/models` | — | 模型别名列表：`default / fast / deep` |
| POST | `/api/agent/invoke` | `{thread_id, model, message, attachments[]}` | `{answer, tool_calls, attachments[]}` |
| WS | `/ws/chat` | `{thread_id, model, message, attachments[]}` | `started/tool/attachment/delta/done/error` 事件 |
| GET | `/api/chat/sessions` | `limit?` | 聊天会话列表 |
| GET | `/api/chat/sessions/{thread_id}/messages` | — | 单会话消息历史 |
| PATCH | `/api/chat/sessions/{thread_id}` | `{title}` | 重命名后的会话 |
| DELETE | `/api/chat/sessions/{thread_id}` | — | `{ok: true}` |

### MicroDesign / Feed / Poster / News

| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/microdesign/schema` | — | 支持的 `blocks/actions/styles` |
| GET | `/api/feed/microdesign` | `keyword?, limit?` | `MicroDesignPost[]`（C 关键词帖子，避免占用 B 的 `/api/feed`） |
| GET | `/api/feed/recommend` | `query?, media_kind?, limit?, refresh?` | `RecommendationFeed` |
| GET | `/api/poster/catalog/{provider_id}/{source_id}` | `media_kind?` | `PosterSpec` |
| GET | `/api/poster/{provider_id}/{remote_id}` | — | `PosterSpec` |
| GET | `/api/news` | `limit?, refresh?` | `NewsFeed` |
| GET | `/api/news/{news_id}` | — | `NewsItem` |

### Resource / Play / Upload

| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/resources/providers` | `probe?` | Provider 列表与可选健康检查 |
| GET | `/api/resources/search` | `keyword` | 多源聚合搜索结果 |
| GET | `/api/resources/{provider_id}/{remote_id}` | — | 资源站详情、线路、剧集 |
| GET | `/api/sources/search` | `movie_name` | 兼容旧播放器的扁平源列表 |
| GET | `/api/sources/parse` | `source_id=provider:remote_id` | 兼容旧播放器的单条播放地址 |
| GET | `/api/play/resolve` | `provider_id, remote_id` | `PlayDescriptor` |
| POST | `/api/uploads` | `multipart file` | `AssetRecord` |
| GET | `/api/assets/{asset_id}` | — | 上传资产文件 |

### Flutter 必须识别的附件类型

| type | payload |
|---|---|
| `recommendation_feed` | 推荐帖子 Feed |
| `microdesign_poster` | 互动海报 |
| `interactive_cards` | 聊天气泡内交互卡片集合 |
| `news_feed` | 资讯流 |

### Flutter 必须优先支持的 Action

| action | 说明 |
|---|---|
| `openPoster` | 打开 `/api/poster/catalog/{provider}/{source_id}` |
| `openResourcePoster` | 打开 `/api/poster/{provider_id}/{remote_id}` |
| `resolveAndPlay` | 请求 `/api/play/resolve` 后交给播放器 |

## 数据模型

### Movie
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | TMDB id |
| title | string | 中文标题 |
| original_title | string? | 原始/英文标题 |
| year | int? | 年份 |
| genres | string[] | 类型标签 |
| rating | float? | 评分 |
| overview | string? | 简介 |
| poster_url | string? | TMDB 海报 |
| backdrop_url | string? | 背景图 |
| directors | string[] | 导演 |
| cast | string[] | 主演 |

### Post（帖子卡片）
| 字段 | 类型 | 说明 |
|------|------|------|
| movie | Movie | 电影 |
| recommend_reason | string | AI 推荐理由 |
| has_video_source | bool | 有在线源 |
| has_bilibili | bool | 有 B站解说 |
| poster_url | string? | C 的 Micro Design 海报，空则回退 movie.poster_url |

### VideoSource
| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 源标识 |
| name | string | 源名称 |
| quality | string? | 清晰度 |
| type | string | web / bilibili / netdisk |
| play_url | string? | 解析后地址（m3u8/mp4） |
| cover | string? | B站封面 |
| play_count | int? | B站播放量 |

### UserPreference
| 字段 | 类型 | 说明 |
|------|------|------|
| liked_genres | string[] | 喜欢类型 |
| disliked_genres | string[] | 不喜欢类型 |
| free_text | string? | 自由口味描述 |

## 接口清单

### 共建
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查（F7 连接测试） |

### 成员 B（feed）
| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/feed` | `refresh: bool` | `Post[]` |
| GET | `/api/discovery` | `page?` | `Movie[]` |
| GET | `/api/movie/{movie_id}` | — | `Movie` |
| POST | `/api/preferences` | `UserPreference` | `{ok}` |
| GET | `/api/preferences` | — | `UserPreference` |
| POST | `/api/feedback` | `{movie_id, liked}` | `{ok}` |
| GET | `/api/history` | — | `WatchHistoryItem[]` |
| POST | `/api/history/record` | `{movie_id, title}` | `{ok}` |
| GET | `/api/collections` | — | `CollectionItem[]` |
| POST | `/api/collections/toggle` | `{movie_id, title, poster_url?}` | `{ok, is_collected}` |

### 成员 A（sources）
| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/sources/search` | `movie_name` | `VideoSource[]` |
| GET | `/api/sources/parse` | `source_id` | `VideoSource`（含 play_url） |
| GET | `/api/bilibili/search` | `keyword` | `VideoSource[]` |

### 成员 C（creative）
| 方法 | 路径 | 入参 | 返回 |
|------|------|------|------|
| GET | `/api/poster/{movie_id}` | `style?` | `{poster_url, ...}` |
| GET | `/api/news` | — | `[{title, summary, source}]` |
| WS | `/ws/chat` | text → | `{role, content, movies[]}` |

## 前端路由契约
| 路由名 | 页面 | 归属 |
|--------|------|------|
| `/` | 主壳（底部导航） | 共建 |
| `/movie-detail/:movieId` | 电影详情 | B |
| `/player` | 播放器 | A |
| `/webview-player` | WebView 降级播放 | A |
| `/preference` | 偏好设置 | B |
| `/history` | 观影历史 | B |
| `/settings` | 设置（连接+偏好入口） | A/B |
