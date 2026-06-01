# API 接口契约（Day 1 共建，前后端共同遵守）

> 任何字段改动需三人同步，并同时改 Flutter `lib/models/` 与后端 `models/schemas.py`。
> Base URL 由手机端设置页配置（PC 的 `http://IP:Port`）。

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
| GET | `/api/movie/{movie_id}` | — | `Movie` |
| POST | `/api/preferences` | `UserPreference` | `{ok}` |
| POST | `/api/feedback` | `{movie_id, liked}` | `{ok}` |

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
