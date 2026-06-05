# CineNest 后端 Agent 模块说明

> 当前版本：后端 `1.2.0`，MicroDesign 协议 `microdesign.v1.1`。
> 面向：后端协作者、Flutter 前端、后续接手的 AI 编码助手。
> 范围：FastAPI、LangChain Agent、多源播放资源、豆瓣/TMDB 资料、推荐 Feed、聊天卡片、资讯、上传资产、统一播放解析。

## 1. 模块定位

CineNest 后端是 PC 端算力中心，Flutter 是交互界面。后端负责把用户意图变成“可验证的影视资料 + 可播放资源 + Flutter 可动态渲染的 JSON”。

核心链路：

```text
用户输入
-> Agent 理解意图
-> Tool 调用 Catalog / Resource / News / MicroDesign
-> Catalog 查豆瓣和 TMDB 资料
-> Resource 并发查 20 个 MacCMS 源
-> Recommendation 只保留有真实资源的候选
-> MicroDesign 输出 blocks/actions
-> Flutter 渲染帖子、聊天卡片、互动海报、播放入口
```

重要边界：

- 首页、普通浏览、播放器优先走确定性 REST。
- 聊天、复杂推荐、图片/文件理解走 Agent。
- Flutter 不解析自然语言里的电影字段，只消费 `attachments`、`blocks`、`actions`。
- 事实字段必须来自 Tool：评分、封面、简介、播放源、播放地址不能靠模型编。

## 2. 当前已完成能力

### P0：Agent 基座、模型选择、持久化

已完成：

- FastAPI 应用入口：`cine_net_backend/main.py`
- OpenAI Chat Completions 兼容模型工厂：`services/llm/factory.py`
- 模型别名接口：`GET /api/agent/models`
- REST Agent：`POST /api/agent/invoke`
- WebSocket Agent：`WS /ws/chat`
- REST/WS 均支持 `model` 字段。
- REST/WS 均支持 `attachments` 字段。
- LangGraph Checkpointer 从内存切到 SQLite：`services/agent/factory.py`
- 聊天会话和消息落 SQLite：`services/chat/`
- 会话接口：`/api/chat/sessions`

模型别名：

| model | 说明 |
|---|---|
| `default` | 默认模型，读取 `LLM_MODEL` |
| `fast` | 快速模型，读取 `LLM_MODEL_FAST`，未填则回退 `LLM_MODEL` |
| `deep` | 深度模型，读取 `LLM_MODEL_DEEP`，未填则回退 `LLM_MODEL` |

### P1：MicroDesign v1.1 和聊天交互卡片

已完成：

- MicroDesign 协议升级到 `microdesign.v1.1`
- 协议说明接口：`GET /api/microdesign/schema`
- 新增 Agent Tool：`build_interactive_answer`
- Agent 可以返回 `interactive_cards` 附件。
- 聊天答案里可以挂载：
  - 可播放电影介绍卡 `playableMovieCard`
  - 电影横向轮播 `movieCarousel`
  - 评价/推荐理由卡 `reviewQuoteCard`
  - 来源追踪卡 `sourceTraceCard`
  - 资讯卡 `newsCard`
  - 图片组 `mediaGallery`
  - 视频讲解卡 `videoExplainCard`

### P2：资讯流

已完成：

- 资讯服务：`services/news/`
- 资讯 API：
  - `GET /api/news`
  - `GET /api/news/{news_id}`
- 资讯 Tool：`collect_movie_news`
- 资讯持久化到 SQLite：`news_items`
- 当前资讯先从 Catalog 热门作品生成结构化影视资讯，后续可以替换成真实资讯源爬取/聚合。

### P3：图片/文件上传与多模态输入

已完成：

- 上传接口：`POST /api/uploads`
- 资产读取：`GET /api/assets/{asset_id}`
- 资产记录落 SQLite：`assets`
- 图片附件可进入 Agent 多模态输入。
- 非图片文件先存储，并作为文本说明传给 Agent；后续接 RAG 时复用 `asset_id`。

### P4：统一播放解析和后续 Provider 骨架

已完成：

- 统一播放解析：`GET /api/play/resolve`
- 返回 Flutter 播放器消费的 `PlayDescriptor`
- 已注册 20 个启用 MacCMS 源。
- 已预留但默认禁用的 Provider：
  - B站：`bilibili`
  - 百度网盘：`baidu_netdisk`
  - Alist：`alist`
  - PC 本地：`pc_local`
- 非 MacCMS Provider 目前返回“已注册但未实现”，不会影响 20 个 MacCMS 源。

## 3. 关键目录

```text
cine_net_backend/
├── main.py                         # FastAPI 入口
├── config.py                       # .env 配置
├── db/database.py                  # SQLite 表结构
├── routers/
│   ├── agent.py                    # /api/agent/*
│   ├── chat.py                     # /ws/chat + 聊天历史
│   ├── microdesign.py              # /api/microdesign/schema
│   ├── feed.py                     # /api/feed/recommend
│   ├── poster.py                   # /api/poster/*
│   ├── resources.py                # /api/resources/*
│   ├── sources.py                  # 兼容旧播放接口
│   ├── news.py                     # /api/news
│   ├── play.py                     # /api/play/resolve
│   └── uploads.py                  # /api/uploads /api/assets/*
├── services/
│   ├── llm/                        # OpenAI 兼容模型工厂
│   ├── agent/                      # LangChain Agent、附件提取、流式事件
│   ├── chat/                       # 聊天会话持久化
│   ├── assets/                     # 上传资产
│   ├── resources/                  # 资源站 Provider 和聚合
│   ├── catalog/                    # 豆瓣 / TMDB
│   ├── recommendation/             # 资料 + 资源联合推荐
│   ├── microdesign/                # blocks/actions 组合器
│   ├── news/                       # 资讯流
│   ├── play/                       # 播放解析
│   └── tools/                      # Agent Tool 注册中心
├── scripts/                        # smoke 验收脚本
└── tests/                          # 单元测试
```

## 4. 环境配置

`.env` 放在 `cine_net_backend/.env`，不要提交。

```dotenv
# OpenAI Chat Completions 兼容聚合站
LLM_API_KEY=你的聚合站Key
LLM_BASE_URL=https://你的聚合站/v1
LLM_MODEL=默认模型ID
LLM_MODEL_FAST=可选快速模型ID
LLM_MODEL_DEEP=可选深度模型ID
LLM_TEMPERATURE=0.2
LLM_TIMEOUT_SECONDS=90
LLM_MAX_RETRIES=2

# TMDB 官方 API Read Access Token，可不填
TMDB_READ_ACCESS_TOKEN=你的TMDB Read Access Token

# 本地 SQLite 和上传资产，可不填
DATABASE_PATH=cinenest.db
AGENT_CHECKPOINT_DB_PATH=agent_checkpoints.sqlite
ASSET_DIR=uploads
ASSET_MAX_BYTES=10485760
ASSET_PUBLIC_BASE_URL=
```

说明：

- 不填 LLM：Feed、Catalog、Resource、Poster、News、Play REST 仍可用；Agent 不可用。
- 不填 TMDB：豆瓣仍可用；TMDB Provider 自动跳过。
- `LLM_MODEL_FAST` / `LLM_MODEL_DEEP` 不填时会回退默认模型。
- 上传文件默认存在 `cine_net_backend/uploads/`，已被 `.gitignore` 忽略。

## 5. 启动

PowerShell 先设置 UTF-8：

```powershell
$env:PYTHONIOENCODING='utf-8'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
```

启动后端：

```powershell
cd cine_net_backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Swagger：

```text
http://127.0.0.1:8000/docs
```

手机访问用 PC 局域网 IP：

```text
http://PC-IP:8000
```

## 6. API 契约

### 6.1 健康检查

```http
GET /api/health
```

关键字段：

```json
{
  "status": "ok",
  "service": "CineNest Backend",
  "version": "1.2.0",
  "llm_configured": true,
  "provider_count": 24,
  "enabled_provider_count": 20,
  "microdesign_schema_version": "microdesign.v1.1"
}
```

`provider_count=24` 是 20 个 MacCMS 源 + 4 个默认禁用的后续 Provider 骨架。

### 6.2 模型列表

```http
GET /api/agent/models
```

返回：

```json
[
  {
    "id": "default",
    "label": "默认模型",
    "model": "gemini-3.5-flash",
    "configured": true
  },
  {
    "id": "fast",
    "label": "快速模型",
    "model": "gemini-3.5-flash",
    "configured": true
  },
  {
    "id": "deep",
    "label": "深度模型",
    "model": "gemini-3.5-flash",
    "configured": true
  }
]
```

Flutter 聊天页模型下拉直接用 `id`，不要传真实供应商模型名。

### 6.3 Agent REST

```http
POST /api/agent/invoke
Content-Type: application/json
```

请求：

```json
{
  "thread_id": "user-001",
  "model": "default",
  "message": "推荐几部功夫熊猫相关电影，最好能直接播放",
  "attachments": [
    {
      "asset_id": "可选",
      "type": "image",
      "url": "可选",
      "mime": "image/png",
      "filename": "poster.png"
    }
  ]
}
```

返回：

```json
{
  "thread_id": "user-001",
  "model": "default",
  "answer": "已帮你整理了可播放候选。",
  "tool_calls": [
    {
      "name": "build_interactive_answer",
      "args": {
        "query": "功夫熊猫",
        "limit": 3
      }
    }
  ],
  "attachments": [
    {
      "type": "interactive_cards",
      "schema_version": "microdesign.v1.1",
      "payload": {
        "schema_version": "microdesign.v1.1",
        "cards": []
      }
    }
  ]
}
```

前端规则：

- `answer` 渲染文本。
- `attachments` 渲染结构化卡片。
- 不要从 `answer` 里抠评分、封面、播放地址。

### 6.4 Agent WebSocket

连接：

```text
ws://PC-IP:8000/ws/chat
```

发送 JSON：

```json
{
  "thread_id": "user-001",
  "model": "fast",
  "message": "想看轻松动画，给我可播放卡片",
  "attachments": []
}
```

事件：

| type | 用法 |
|---|---|
| `started` | 显示思考中 |
| `tool_started` | 可选显示正在检索 |
| `tool_finished` | 调试日志，正式 UI 可忽略 |
| `attachment` | 立即渲染 `data.payload` |
| `delta` | 追加文本 |
| `done` | 关闭加载态 |
| `error` | 显示错误和重试 |

典型顺序：

```text
started -> tool_started -> tool_finished -> attachment -> delta -> done
```

### 6.5 聊天历史

```http
GET /api/chat/sessions
GET /api/chat/sessions/{thread_id}/messages
PATCH /api/chat/sessions/{thread_id}
DELETE /api/chat/sessions/{thread_id}
```

重命名请求：

```json
{
  "title": "周末动画片单"
}
```

### 6.6 MicroDesign Schema

```http
GET /api/microdesign/schema
```

返回：

```json
{
  "schema_version": "microdesign.v1.1",
  "blocks": [
    "posterRow",
    "banner",
    "rating",
    "tagRow",
    "heading",
    "text",
    "videoBar",
    "imageSwiper",
    "playableMovieCard",
    "movieCarousel",
    "reviewQuoteCard",
    "sourceTraceCard",
    "newsCard",
    "mediaGallery",
    "videoExplainCard"
  ],
  "actions": [
    "openPoster",
    "openResourcePoster",
    "resolveAndPlay"
  ],
  "styles": ["warm", "neon", "contrast"]
}
```

Flutter 建议实现一个统一 `BlockRenderer`，未知 block 静默跳过或显示兜底，不要崩。

### 6.7 推荐 Feed

```http
GET /api/feed/recommend?query=功夫熊猫&media_kind=movie&limit=10&refresh=false
```

返回 `RecommendationFeed`：

```json
{
  "schema_version": "microdesign.v1.1",
  "query": "功夫熊猫",
  "posts": [
    {
      "schema_version": "microdesign.v1.1",
      "id": "wujin:89203",
      "catalog_id": "douban:1783457",
      "title": "功夫熊猫",
      "cover_url": "https://...",
      "rating": 8.3,
      "recommend_reason": "8.3 分，已确认 3 个可用资源站。",
      "has_video_source": true,
      "source_count": 3,
      "primary_resource": {
        "provider_id": "wujin",
        "remote_id": "89203"
      },
      "blocks": [
        {
          "type": "playableMovieCard",
          "data": {
            "title": "功夫熊猫",
            "cover": "https://...",
            "year": "2008",
            "rating": 8.3,
            "rating_label": "豆瓣",
            "summary": "...",
            "genres": ["动画", "喜剧"],
            "source_count": 3,
            "actions": [
              {"type": "resolveAndPlay", "data": {"provider_id": "wujin", "remote_id": "89203"}},
              {"type": "openPoster", "data": {"catalog_provider_id": "douban", "catalog_source_id": "1783457"}}
            ]
          }
        }
      ],
      "actions": [
        {
          "type": "openPoster",
          "label": "查看互动海报",
          "data": {
            "catalog_provider_id": "douban",
            "catalog_source_id": "1783457",
            "media_kind": "movie"
          }
        },
        {
          "type": "resolveAndPlay",
          "label": "立即播放",
          "data": {
            "provider_id": "wujin",
            "remote_id": "89203"
          }
        }
      ]
    }
  ]
}
```

说明：

- `posts` 已经过真实播放资源确认。
- `refresh=false` 时优先读内存和 SQLite 缓存。
- Agent Tool 内部会用 `refresh=true`，避免聊天拿到过旧的推荐。

### 6.8 互动海报

```http
GET /api/poster/catalog/{provider_id}/{source_id}?media_kind=movie
GET /api/poster/{resource_provider_id}/{remote_id}
```

返回 `PosterSpec`，核心仍是 `blocks/actions`：

```json
{
  "schema_version": "microdesign.v1.1",
  "style": "warm",
  "title": "功夫熊猫",
  "blocks": [
    {"type": "banner", "data": {}},
    {"type": "rating", "data": {}},
    {"type": "tagRow", "data": {}},
    {"type": "text", "data": {}},
    {
      "type": "videoBar",
      "data": {},
      "action": {
        "type": "resolveAndPlay",
        "data": {
          "provider_id": "wujin",
          "remote_id": "89203",
          "play_url": "https://.../index.m3u8"
        }
      }
    }
  ]
}
```

### 6.9 播放资源

列 Provider：

```http
GET /api/resources/providers
GET /api/resources/providers?probe=true
```

搜索：

```http
GET /api/resources/search?keyword=功夫熊猫
```

详情：

```http
GET /api/resources/{provider_id}/{remote_id}
```

兼容旧播放器接口：

```http
GET /api/sources/search?movie_name=功夫熊猫
GET /api/sources/parse?source_id=wujin:89203
```

正式推荐播放器优先接：

```http
GET /api/play/resolve?provider_id=wujin&remote_id=89203
```

返回 `PlayDescriptor`：

```json
{
  "type": "direct",
  "play_url": "https://.../index.m3u8",
  "headers": {},
  "expires_at": null,
  "fallback_web_url": null,
  "provider_id": "wujin",
  "remote_id": "89203",
  "title": "功夫熊猫",
  "line_name": "wjm3u8",
  "episode_name": "HD中字"
}
```

播放器建议：

- MacCMS 直链：Flutter 直接把 `play_url` 交给播放器。
- B站/网盘/Alist/本地：后续仍走同一个 `PlayDescriptor`，只是在后端 Provider 内部处理鉴权、刷新、Range、本地文件等细节。

### 6.10 Catalog

```http
GET /api/catalog/providers
GET /api/catalog/hot?media_kind=movie&limit=20
GET /api/catalog/search?query=功夫熊猫&media_kind=movie&limit=20
GET /api/catalog/{provider_id}/{source_id}?media_kind=movie
```

当前资料源：

- 豆瓣：可用作中文资料、评分、封面来源。
- TMDB：需要 `TMDB_READ_ACCESS_TOKEN`，可补充海报、背景图、简介、类型。

### 6.11 资讯

```http
GET /api/news?limit=10&refresh=false
GET /api/news/{news_id}
```

返回 `NewsFeed`：

```json
{
  "schema_version": "microdesign.v1.1",
  "items": [
    {
      "id": "news-douban-1783457",
      "title": "功夫熊猫 正在热映推荐",
      "summary": "结合评分、封面和可播放资源生成的影视资讯。",
      "blocks": [
        {
          "type": "newsCard",
          "data": {
            "title": "功夫熊猫 正在热映推荐",
            "source": "CineNest Agent",
            "published_at": "1 小时前",
            "summary": "结合评分、封面和可播放资源生成的影视资讯。",
            "cover": "https://...",
            "tags": ["动画", "2008"]
          },
          "action": {"type": "openPoster", "data": {"catalog_provider_id": "douban", "catalog_source_id": "1783457"}}
        },
        {
          "type": "mediaGallery",
          "data": {"title": "相关图片", "layout": "swiper", "urls": ["https://..."]}
        }
      ],
      "actions": [
        {"type": "openPoster", "data": {"catalog_provider_id": "douban", "catalog_source_id": "1783457"}}
      ]
    }
  ]
}
```

### 6.12 上传资产

上传：

```http
POST /api/uploads
Content-Type: multipart/form-data
```

字段：

```text
file=<图片或文件>
```

返回：

```json
{
  "asset_id": "1859ce3182b141d788d1e7f190d4369c",
  "filename": "poster.png",
  "mime": "image/png",
  "size": 12345,
  "url": "/api/assets/1859ce3182b141d788d1e7f190d4369c",
  "kind": "image"
}
```

读取：

```http
GET /api/assets/{asset_id}
```

Agent 输入附件：

```json
{
  "asset_id": "1859ce3182b141d788d1e7f190d4369c",
  "type": "image",
  "mime": "image/png",
  "filename": "poster.png"
}
```

## 7. MicroDesign 前端渲染规则

### 7.1 Block

| block | 典型用途 |
|---|---|
| `posterRow` | 旧版紧凑帖子 |
| `playableMovieCard` | 可播放电影卡，推荐列表和聊天都可用 |
| `movieCarousel` | 多电影横向轮播 |
| `reviewQuoteCard` | AI 总结的推荐理由/评价卡 |
| `sourceTraceCard` | 展示命中的资源站数量、首选源 |
| `newsCard` | 资讯列表卡 |
| `mediaGallery` | 海报/剧照横向图组 |
| `videoExplainCard` | 视频讲解入口 |
| `banner` | 海报详情头图 |
| `rating` | 评分 |
| `tagRow` | 标签 |
| `heading` | 标题 |
| `text` | 文本段落 |
| `videoBar` | 可点击播放条 |
| `imageSwiper` | 图片轮播 |

Flutter 渲染建议：

- `playableMovieCard`：读 `cover/title/year/rating/rating_label/summary/genres/source_count/actions`。
- `movieCarousel`：读 `title/items[]`，每项读 `cover/title/year/rating/action`。
- `reviewQuoteCard`：适合聊天气泡里展示“为什么推荐”。
- `sourceTraceCard`：读 `query/items[]`，每项 `key/label/count/status`，`status` 只用 `ok/empty`。
- `newsCard`：读 `title/source/published_at/summary/cover/tags`，点击走信封级 `action`。
- `mediaGallery`：读 `title/layout/urls`，`layout` 用 `swiper` 或 `grid`。
- `videoExplainCard`：读 `title/cover/up/duration/play_count`，点击走信封级 `action`。
- `videoBar`：点击走 `resolveAndPlay` 或直接用 `play_url`。

### 7.2 Action

| action | Flutter 行为 |
|---|---|
| `openPoster` | 打开互动海报页，请求 `/api/poster/catalog/{provider}/{source_id}` |
| `openResourcePoster` | 没有 Catalog ID 时，请求 `/api/poster/{provider_id}/{remote_id}` |
| `resolveAndPlay` | 请求 `/api/play/resolve`，拿到 `PlayDescriptor` 后播放 |

## 8. Agent Tool 清单

| Tool | 输出附件 | 用途 |
|---|---|---|
| `get_backend_status` | 无 | 查看后端能力、Provider、Catalog、LLM 状态 |
| `search_playable_resources` | 无 | 搜索真实播放资源 |
| `get_playable_resource_detail` | 无 | 解析资源站条目线路和剧集 |
| `build_microdesign_posts` | 无 | 旧版资源帖子生成 |
| `browse_catalog_hot` | 无 | 查热门影视资料 |
| `search_catalog_movies` | 无 | 查豆瓣/TMDB 影视资料 |
| `build_recommendation_feed` | `recommendation_feed` | 生成可播放推荐帖子 |
| `build_catalog_microdesign_poster` | `microdesign_poster` | 生成互动海报 |
| `build_interactive_answer` | `interactive_cards` | 聊天用交互卡片集合 |
| `collect_movie_news` | `news_feed` | 影视资讯卡片 |

附件类型：

```text
recommendation_feed
microdesign_poster
interactive_cards
news_feed
```

前端收到 `attachment` 时看 `data.type`，再把 `data.payload` 交给对应渲染器。

## 9. 后续扩展规范

### 9.1 新增 MacCMS 源

只改：

```text
cine_net_backend/services/resources/providers.yaml
```

新增：

```yaml
- id: demo
  name: 示例资源
  endpoint: https://example.com/api.php/provide/vod
  kind: maccms
  enabled: true
```

### 9.2 新增 B站/网盘/Alist/本地 Provider

新建 Provider，实现统一方法：

```text
search(keyword, limit)
detail(remote_id)
health()
```

返回统一模型：

```text
ResourceCandidate
MediaResourceDetail
PlayLine
Episode
PlayDescriptor
```

外部接口不变，Flutter 仍然接 `/api/resources/*` 和 `/api/play/resolve`。

### 9.3 新增资料源

在 `services/catalog/` 新增 Provider，返回统一 `CatalogMovie`，再在 `providers.yaml` 里注册。不要让 Flutter 直接连第三方资料 API。

### 9.4 新增 Agent Tool

步骤：

1. 在 `services/tools/` 新建工具文件。
2. 使用 `@tool` 声明。
3. 返回 JSON 字符串，`ensure_ascii=False`。
4. 在 `services/tools/registry.py` 注册。
5. 如果输出要给 Flutter 渲染，在 `services/agent/factory.py` 的 `_ATTACHMENT_TYPES` 加附件类型。

### 9.5 图片生成

建议后续作为 Tool：

```text
generate_poster_background(movie, style)
-> 返回 image_url / asset_id
-> composer 写入 banner.data.image 或 mediaGallery
```

不要阻塞首页首屏。可以先返回豆瓣/TMDB 海报，再异步生成 AI 图。

### 9.6 文件 RAG

上传文件已经有 `asset_id` 和 SQLite 记录。后续做 RAG 时，把文件解析、切片、向量化挂到 `services/assets/` 或新 `services/rag/`，Agent 通过 Tool 调用，不要直接在聊天路由里塞复杂逻辑。

## 10. 验收测试

所有命令在 PowerShell 下执行：

```powershell
$env:PYTHONIOENCODING='utf-8'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
cd cine_net_backend
```

### 10.1 离线/确定性测试

```powershell
python -m unittest discover -s tests -v
Get-ChildItem -Recurse -Filter *.py | ForEach-Object { python -m py_compile $_.FullName }
git diff --check
```

预期：

- 单元测试全部 OK。
- Python 编译无错误。
- diff 无空白错误。

### 10.2 P0~P4 综合 smoke

```powershell
python scripts\smoke_p0_p4.py
```

验证内容：

- `GET /api/agent/models`
- `GET /api/microdesign/schema`
- `POST /api/uploads`
- `GET /api/assets/{asset_id}`
- `GET /api/news`
- `GET /api/feed/recommend?query=功夫熊猫&refresh=true`
- `GET /api/play/resolve`

已实测通过结果：

```text
schema=microdesign.v1.1
news blocks=["newsCard", "mediaGallery"]
feed first title=功夫熊猫
feed first blocks=["playableMovieCard"]
actions=["openPoster", "resolveAndPlay"]
play type=direct
play_url=https://.../index.m3u8
```

### 10.3 资源真实联网

```powershell
python scripts\smoke_resources.py
```

说明：验证 20 个启用 MacCMS 源并发搜索和播放列表解析。单源失败只进入 trace，不应拖垮整体。

### 10.4 Catalog / Feed / Poster

```powershell
python scripts\smoke_catalog.py
python scripts\smoke_step3.py
```

可指定影片：

```powershell
python scripts\smoke_step3.py "功夫熊猫"
```

### 10.5 Agent Tool Calling

需要 `.env` 已配置 LLM：

```powershell
python scripts\smoke_llm.py
python scripts\smoke_agent_step2.py
python scripts\smoke_agent_step3.py
python scripts\smoke_ws_step3.py
```

验收重点：

- Agent 产生 `tool_calls`。
- REST 返回 `attachments`。
- WS 收到 `attachment` 事件。
- 附件 `schema_version` 为 `microdesign.v1.1`。

## 11. 给 Flutter 的最短接入路线

首页推荐：

```text
GET /api/feed/recommend?query=功夫熊猫&limit=10
-> 渲染 posts[].blocks
-> 点击 openPoster / resolveAndPlay
```

聊天页：

```text
WS /ws/chat
-> 发送 {thread_id, model, message, attachments}
-> delta 渲染文本
-> attachment 渲染卡片
```

海报详情：

```text
openPoster
-> GET /api/poster/catalog/{catalog_provider_id}/{catalog_source_id}
-> 渲染 PosterSpec.blocks
```

播放器：

```text
resolveAndPlay
-> GET /api/play/resolve?provider_id=...&remote_id=...
-> media_kit / Flutter 播放器打开 play_url
```

上传图片：

```text
POST /api/uploads
-> 拿 asset_id
-> 发送给 /ws/chat 或 /api/agent/invoke 的 attachments
```

## 12. 已知边界

当前已经能支撑：

- 多源真实播放推荐。
- 豆瓣/TMDB 资料聚合。
- 聊天推荐卡片。
- 动态帖子和互动海报 JSON。
- 资讯卡片雏形。
- 图片多模态输入。
- 文件上传和后续 RAG 预留。
- 播放解析统一入口。

后置能力：

- B站登录态、会员资源、弹幕。
- 百度网盘解析。
- Alist 挂载。
- PC 本地 HTTP Range 流播放。
- 真实影视资讯源采集。
- AI 图片生成背景图。
- 用户长期偏好和跨设备同步。

这些后置能力应该作为 Provider 或 Tool 扩展，不推翻 `microdesign.v1.1` 和现有 REST/WS 契约。
