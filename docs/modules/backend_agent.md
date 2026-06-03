# CineNest 后端 Agent 模块说明

> 面向后端协作者、Flutter 前端、以及后续接手的 AI 编码助手。  
> 当前模块范围：FastAPI 后端、LangChain Agent、影视资料 Catalog、播放资源 Resource、推荐 Feed、MicroDesign 动态海报、REST/WS 对接协议。

## 1. 一句话说明

这个模块把 PC 端 FastAPI 做成 CineNest 的“影视策展中枢”：

```text
用户想看什么
-> Agent 理解意图
-> Catalog 查豆瓣 / TMDB 资料
-> Resource 聚合 20 个 MacCMS 播放源
-> Recommendation 只保留真实可播放候选
-> MicroDesign 输出 Flutter 可动态渲染的 blocks/actions
```

Flutter 不需要知道资源站怎么抓，也不需要解析 Agent 自然语言。前端只消费稳定 JSON，按 `blocks` 渲染页面，按 `actions` 做点击跳转或播放。

## 2. 当前已经完成什么

### 2.1 后端基础

- FastAPI 应用入口：`cine_net_backend/main.py`
- CORS 已开放，方便手机局域网访问 PC 后端。
- OpenAI Chat Completions 兼容模型工厂：`services/llm/factory.py`
- LangChain v1 `create_agent()` 底座：`services/agent/factory.py`
- REST Agent：`POST /api/agent/invoke`
- WebSocket Agent：`WS /ws/chat`
- `.env` 读取配置：`cine_net_backend/config.py`

### 2.2 播放资源 Resource 层

文件位置：`cine_net_backend/services/resources/`

已完成：

- 20 个 MacCMS 资源站配置：`services/resources/providers.yaml`
- 并发搜索所有启用资源站。
- 单个资源站挂掉只进入 `traces`，不会拖垮整体请求。
- 解析 MacCMS 播放列表格式：
  - 线路分隔：`$$$`
  - 剧集分隔：`#`
  - 标题与 URL 分隔：`$`
- 返回真实 HTTP(S) `m3u8/mp4` 播放地址。
- 兼容 A 组旧接口：`/api/sources/search`、`/api/sources/parse`
- 完整资源接口：`/api/resources/*`

### 2.3 影视资料 Catalog 层

文件位置：`cine_net_backend/services/catalog/`

已完成：

- 豆瓣资料源。
- TMDB 官方 API 资料源。
- `services/catalog/providers.yaml` 配置化启停。
- TMDB 没填 Token 时自动跳过，豆瓣仍可用。
- 多资料源搜索、热门、详情。
- 标题归一化与合并：同名、同类型、年份兼容时合并资料。
- 精确标题排序：例如“星际穿越”排在“《星际穿越》中的科学”前面。
- 合并缓存：从豆瓣 ID 或 TMDB ID 进入时，尽量复用同一份丰富资料。

### 2.4 Recommendation 推荐组合层

文件位置：`cine_net_backend/services/recommendation/`

已完成：

- 先查 Catalog 资料候选。
- 再用 ResourceAggregator 搜索真实播放资源。
- 只输出有真实播放资源的帖子。
- 精确标题和年份优先匹配播放源。
- 首页推荐 Feed 有 5 分钟短缓存，减少重复请求多个资源站。

### 2.5 MicroDesign 动态渲染协议

文件位置：`cine_net_backend/services/microdesign/`

已完成协议版本：

```json
{
  "schema_version": "microdesign.v1"
}
```

核心设计：

- `blocks`：Flutter 要渲染哪些组件。
- `actions`：用户点击后执行什么动作。

这套协议用于：

- 首页推荐帖子。
- 具体互动海报。
- Agent 聊天气泡内嵌推荐卡片。

### 2.6 Agent Tools

文件位置：`cine_net_backend/services/tools/`

当前注册的 8 个工具：

| Tool | 用途 |
|---|---|
| `get_backend_status` | 查看后端能力、LLM 配置、资源站数量、Catalog 状态 |
| `search_playable_resources` | 搜索真实可播放资源 |
| `get_playable_resource_detail` | 解析某个资源站条目的线路与剧集 |
| `build_microdesign_posts` | 仅基于资源搜索结果生成旧版 MicroDesign 帖子 |
| `browse_catalog_hot` | 浏览豆瓣 / TMDB 热门作品 |
| `search_catalog_movies` | 搜索豆瓣 / TMDB 影视资料 |
| `build_recommendation_feed` | 生成 Flutter 可渲染的推荐帖子 |
| `build_catalog_microdesign_poster` | 生成具体作品的互动海报 |

Agent 只看到这些高层工具，不直接看到 20 个资源站。资源站并发、失败隔离、合并排序都由后端服务层处理。

## 3. 目录结构说明

```text
cine_net_backend/
├── main.py                         # FastAPI 入口，挂载全部 router
├── config.py                       # .env 配置读取
├── routers/
│   ├── health.py                   # /api/health
│   ├── resources.py                # 完整播放资源接口
│   ├── sources.py                  # 兼容旧 Flutter 的简化播放源接口
│   ├── catalog.py                  # 豆瓣 / TMDB 资料接口
│   ├── feed.py                     # 推荐帖子 Feed
│   ├── poster.py                   # 互动海报
│   ├── agent.py                    # Agent REST
│   └── chat.py                     # Agent WebSocket
├── services/
│   ├── llm/                        # OpenAI 兼容模型工厂
│   ├── agent/                      # LangChain Agent、REST/WS 协议模型
│   ├── tools/                      # Agent Tool 注册中心
│   ├── resources/                  # MacCMS Provider、播放列表解析、并发聚合
│   ├── catalog/                    # 豆瓣 / TMDB Provider、资料聚合
│   ├── recommendation/             # Catalog + Resource 联合推荐
│   └── microdesign/                # blocks/actions 组合器
├── scripts/
│   ├── smoke_resources.py          # 真实播放资源验收
│   ├── smoke_catalog.py            # Catalog + Feed + Poster 验收
│   ├── smoke_llm.py                # 基础 Agent Tool Calling 验收
│   ├── smoke_agent_step2.py        # Catalog Tool 调度验收
│   ├── smoke_step3.py              # MicroDesign v1 确定性验收
│   ├── smoke_agent_step3.py        # Agent 附件验收
│   └── smoke_ws_step3.py           # WebSocket 附件验收
└── tests/                          # 单元测试
```

## 4. 配置说明

配置文件由 `cine_net_backend/config.py` 读取，`.env` 放在 `cine_net_backend/.env`。

当前仓库没有可靠的 `.env.example`，如果本地没有 `.env`，手动创建即可。

```dotenv
# OpenAI Chat Completions 兼容聚合站
LLM_API_KEY=你的聚合站Key
LLM_BASE_URL=https://你的聚合站/v1
LLM_MODEL=聚合站模型ID
LLM_TEMPERATURE=0.2
LLM_TIMEOUT_SECONDS=90
LLM_MAX_RETRIES=2

# TMDB 官方 API Read Access Token，可不填
TMDB_READ_ACCESS_TOKEN=你的TMDB Read Access Token
```

说明：

- 不填 LLM：资源搜索、Catalog、Feed、Poster REST 仍可用；Agent 不可用。
- 不填 TMDB：豆瓣仍可用；TMDB Provider 显示 `configured: false` 并自动跳过。
- `.env` 已被 `.gitignore` 忽略，不要提交 Key。

TMDB Token 获取：

1. 登录或注册 `https://www.themoviedb.org/signup`
2. 打开 `https://www.themoviedb.org/settings/api`
3. 申请 API 权限。
4. 复制较长的 `API Read Access Token`，不是较短的 v3 `API Key`。
5. 写入 `TMDB_READ_ACCESS_TOKEN` 后重启 FastAPI。

TMDB 官方文档：

- `https://developer.themoviedb.org/docs/authentication-application`
- `https://developer.themoviedb.org/docs/search-and-query-for-details`

## 5. 服务启动

PowerShell 建议先显式设置 UTF-8：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:PYTHONIOENCODING = "utf-8"
```

启动：

```powershell
cd cine_net_backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Swagger：

```text
http://127.0.0.1:8000/docs
```

手机端局域网访问时，Base URL 使用 PC 的局域网地址：

```text
http://PC-IP:8000
```

## 6. API 总览

### 6.1 健康检查

```http
GET /api/health
```

返回后端状态、LLM 是否配置、资源站数量、Catalog Provider 状态、MicroDesign 协议版本。

关键字段：

```json
{
  "status": "ok",
  "service": "CineNest Backend",
  "version": "1.1.0",
  "llm_configured": true,
  "provider_count": 20,
  "enabled_provider_count": 20,
  "microdesign_schema_version": "microdesign.v1"
}
```

### 6.2 播放资源接口

列出资源站：

```http
GET /api/resources/providers
GET /api/resources/providers?probe=true
```

搜索所有启用资源站：

```http
GET /api/resources/search?keyword=功夫熊猫
```

返回 `ResourceSearchResponse`：

```json
{
  "keyword": "功夫熊猫",
  "items": [
    {
      "normalized_title": "功夫熊猫",
      "title": "功夫熊猫",
      "category": "喜剧片",
      "cover_url": "...",
      "remarks": "HD中字",
      "year": "2008",
      "sources": [
        {
          "provider_id": "wujin",
          "provider_name": "无尽资源",
          "remote_id": "89203",
          "title": "功夫熊猫"
        }
      ]
    }
  ],
  "traces": []
}
```

解析完整资源详情：

```http
GET /api/resources/wujin/89203
```

返回 `MediaResourceDetail`：

```json
{
  "provider_id": "wujin",
  "provider_name": "无尽资源",
  "remote_id": "89203",
  "title": "功夫熊猫",
  "play_lines": [
    {
      "name": "wjm3u8",
      "episodes": [
        {
          "name": "HD中字",
          "play_url": "https://.../index.m3u8"
        }
      ]
    }
  ]
}
```

### 6.3 兼容旧 Flutter 的播放源接口

搜索扁平源列表：

```http
GET /api/sources/search?movie_name=功夫熊猫
```

解析首条可播放地址：

```http
GET /api/sources/parse?source_id=wujin:89203
```

返回：

```json
{
  "id": "wujin:89203",
  "name": "无尽资源 · wjm3u8 · HD中字",
  "quality": "HD中字",
  "type": "web",
  "play_url": "https://.../index.m3u8",
  "cover": "..."
}
```

给 A 组播放器的建议：

- 快速联调用 `/api/sources/search` 和 `/api/sources/parse`。
- 正式播放器、选线路、选集、失败切换用 `/api/resources/search` 和 `/api/resources/{provider_id}/{remote_id}`。
- Flutter 拿到 `play_url` 后用 `media_kit` 直接播放，不要让 FastAPI 默认代理整部视频。

### 6.4 Catalog 资料接口

Provider 状态：

```http
GET /api/catalog/providers
```

热门：

```http
GET /api/catalog/hot?media_kind=movie&limit=20
```

搜索：

```http
GET /api/catalog/search?query=功夫熊猫&media_kind=movie&limit=20
```

详情：

```http
GET /api/catalog/douban/1783457?media_kind=movie
GET /api/catalog/tmdb/9502?media_kind=movie
```

注意：

- TMDB 支持独立详情查询。
- 豆瓣条目通常需要先通过热门或搜索进入缓存，再查详情。
- 推荐和海报接口内部会处理这些流程，Flutter 普通开发优先用 `/api/feed/recommend` 和 `/api/poster/catalog/*`。

### 6.5 推荐 Feed

推荐 Feed 是 Flutter 首页最推荐使用的接口：

```http
GET /api/feed/recommend?query=功夫熊猫&media_kind=movie&limit=10
```

无 query 时走热门候选：

```http
GET /api/feed/recommend?limit=10
```

返回 `RecommendationFeed`：

```json
{
  "schema_version": "microdesign.v1",
  "query": "功夫熊猫",
  "posts": [
    {
      "schema_version": "microdesign.v1",
      "id": "wujin:89203",
      "catalog_id": "douban:1783457",
      "title": "功夫熊猫",
      "subtitle": "喜剧片 · HD中字",
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
          "type": "posterRow",
          "data": {
            "cover": "https://...",
            "score": 8.3,
            "summary": "8.3 分，已确认 3 个可用资源站。",
            "tags": ["喜剧片"]
          },
          "action": null
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
  ],
  "catalog_traces": []
}
```

说明：

- `posts` 已经过真实播放资源确认。
- 同一 query 会缓存 5 分钟，减少首页重复等待资源站。
- 首页卡片可以只渲染 `post.blocks` 里的 `posterRow`。
- 点击海报详情用 `openPoster`。
- 点击播放用 `resolveAndPlay`。

### 6.6 互动海报接口

Catalog 条目海报：

```http
GET /api/poster/catalog/douban/1783457?media_kind=movie
```

资源站条目海报：

```http
GET /api/poster/wujin/89203
```

返回 `PosterSpec`：

```json
{
  "schema_version": "microdesign.v1",
  "id": "wujin:89203",
  "catalog_id": "douban:1783457",
  "style": "warm",
  "title": "功夫熊猫",
  "subtitle": "2008 · HD中字",
  "recommend_reason": "根据你的观影意图与当前可用资源，为你精选这部作品。",
  "blocks": [
    {
      "type": "banner",
      "data": {
        "image": "...",
        "poster": "...",
        "title": "功夫熊猫",
        "subtitle": "2008 · HD中字",
        "style": "warm"
      }
    },
    {
      "type": "rating",
      "data": {
        "score": 8.3,
        "label": "豆瓣"
      }
    },
    {
      "type": "videoBar",
      "data": {
        "title": "wjm3u8 · HD中字",
        "cover": "...",
        "play_url": "https://.../index.m3u8",
        "episode_count": 1
      },
      "action": {
        "type": "resolveAndPlay",
        "label": "立即播放",
        "data": {
          "provider_id": "wujin",
          "remote_id": "89203",
          "line_name": "wjm3u8",
          "episode_name": "HD中字",
          "play_url": "https://.../index.m3u8"
        }
      }
    }
  ],
  "actions": []
}
```

## 7. MicroDesign v1 前端协议

### 7.1 Block 列表

Flutter 需要实现一个 `BlockRenderer`，按 `type` 分发：

| Block type | 用途 | 常用字段 |
|---|---|---|
| `posterRow` | 首页和聊天中的紧凑帖子卡片 | `cover`, `score`, `summary`, `tags` |
| `banner` | 互动海报顶部大图 | `image`, `poster`, `title`, `subtitle`, `style` |
| `rating` | 评分 | `score`, `label` |
| `tagRow` | 标签行 | `tags` |
| `heading` | 小标题 | `text` |
| `text` | 推荐理由、简介 | `text` |
| `videoBar` | 可点击播放线路 | `title`, `cover`, `play_url`, `episode_count` |
| `imageSwiper` | 后续剧照或 AI 生图 | `urls` |

当前 Flutter `cine_nest_app/lib/pages/creative/models/content_block.dart` 已有多数类型，但还需要前端补：

- `banner` 枚举。
- `action` 字段解析。
- 对未知 block 的静默跳过。

### 7.2 Action 列表

#### `openPoster`

从推荐帖子打开 Catalog 互动海报：

```json
{
  "type": "openPoster",
  "label": "查看互动海报",
  "data": {
    "catalog_provider_id": "douban",
    "catalog_source_id": "1783457",
    "media_kind": "movie"
  }
}
```

Flutter 执行：

```http
GET /api/poster/catalog/douban/1783457?media_kind=movie
```

#### `openResourcePoster`

旧资源 Feed 没有 Catalog ID 时打开资源站海报：

```json
{
  "type": "openResourcePoster",
  "data": {
    "provider_id": "wujin",
    "remote_id": "89203"
  }
}
```

Flutter 执行：

```http
GET /api/poster/wujin/89203
```

#### `resolveAndPlay`

从帖子播放：

```json
{
  "type": "resolveAndPlay",
  "data": {
    "provider_id": "wujin",
    "remote_id": "89203"
  }
}
```

Flutter 先解析：

```http
GET /api/sources/parse?source_id=wujin:89203
```

从互动海报 `videoBar` 播放时，`action.data.play_url` 已经有当前线路首集 URL。Flutter 可以直接播放，也可以再调用完整资源详情接口获取所有剧集。

### 7.3 样式

后端当前输出三种 `style`：

| style | 适用 |
|---|---|
| `neon` | 科幻、奇幻、动画 |
| `contrast` | 动作、战争、犯罪、悬疑 |
| `warm` | 默认、喜剧、文艺、治愈 |

Flutter 可以根据 `style` 切换颜色、渐变、背景模糊、动效。不要让 Agent 输出任意 CSS 或 Flutter 代码。

## 8. Agent REST 与 WebSocket

### 8.1 REST 调用

```http
POST /api/agent/invoke
Content-Type: application/json

{
  "thread_id": "user-001",
  "message": "推荐两部功夫熊猫系列，最好能直接播放"
}
```

返回：

```json
{
  "thread_id": "user-001",
  "answer": "已为你生成 2 个真实可播放的推荐帖子...",
  "tool_calls": [
    {
      "name": "build_recommendation_feed",
      "args": {
        "query": "功夫熊猫",
        "limit": 2
      }
    }
  ],
  "attachments": [
    {
      "type": "recommendation_feed",
      "schema_version": "microdesign.v1",
      "payload": {
        "schema_version": "microdesign.v1",
        "query": "功夫熊猫",
        "posts": []
      }
    }
  ]
}
```

前端建议：

- `answer` 用于聊天气泡文本。
- `attachments` 用于渲染卡片或互动海报。
- 不要从 `answer` 里解析电影字段。

### 8.2 WebSocket 调用

连接：

```text
ws://PC-IP:8000/ws/chat
```

发送：

```json
{
  "thread_id": "user-001",
  "message": "推荐两部轻松的动画电影"
}
```

事件：

| type | Flutter 行为 |
|---|---|
| `started` | 显示思考中 |
| `tool_started` | 可选显示“正在检索资料/资源” |
| `tool_finished` | 调试日志，正式 UI 可以忽略内容 |
| `attachment` | 渲染 `data.payload` |
| `delta` | 追加 Agent 文本 |
| `done` | 关闭加载态 |
| `error` | 显示错误与重试按钮 |

真实验收过的事件顺序：

```text
started
-> tool_started
-> tool_finished
-> attachment
-> delta
-> done
```

`attachment` 示例：

```json
{
  "type": "attachment",
  "data": {
    "type": "recommendation_feed",
    "schema_version": "microdesign.v1",
    "payload": {
      "query": "功夫熊猫",
      "posts": []
    }
  }
}
```

## 9. 前端对接建议

### 9.1 首页推荐列表

推荐直接调用：

```http
GET /api/feed/recommend?query=功夫熊猫&limit=10
```

渲染逻辑：

1. 遍历 `posts`。
2. 对每个 post 渲染 `blocks` 中的 `posterRow`。
3. 点击卡片优先执行 `openPoster`。
4. 点击播放按钮执行 `resolveAndPlay`。

首页不建议每次都走 Agent。Agent 适合聊天和复杂意图，首页 Feed 用确定性 REST 更稳。

### 9.2 互动海报详情

从 `openPoster` 获取参数：

```text
catalog_provider_id = douban
catalog_source_id = 1783457
media_kind = movie
```

请求：

```http
GET /api/poster/catalog/douban/1783457?media_kind=movie
```

渲染：

1. 按 `blocks` 顺序渲染。
2. `banner` 做顶部视觉。
3. `rating`、`tagRow`、`text` 做信息区。
4. `videoBar` 做线路按钮。
5. 点击 `videoBar.action` 播放。

### 9.3 播放器

快速播放：

```text
resolveAndPlay(provider_id, remote_id)
-> GET /api/sources/parse?source_id={provider_id}:{remote_id}
-> media_kit.open(play_url)
```

完整播放：

```text
GET /api/resources/{provider_id}/{remote_id}
-> 用户选择 line / episode
-> media_kit.open(episode.play_url)
```

FastAPI 默认不代理视频流。这样 PC 后端只是控制面，手机直接拉资源站视频，延迟和带宽压力更低。

例外场景：

| 场景 | 后续做法 |
|---|---|
| B站会员、Cookie、签名短时 URL | 后端负责鉴权和刷新，返回播放描述 |
| PC 本地文件 | 后端提供局域网 HTTP Range 流 |
| 网盘文件 | 后端解析或 Alist 挂载后返回可播放 URL |

### 9.4 聊天页

聊天页使用 `WS /ws/chat`。

Flutter UI 建议：

- 用户消息立即显示。
- `started` 后显示“正在思考”。
- `tool_started` 后显示“正在检索资料/资源”。
- `attachment` 到达后立即渲染推荐卡片，不必等最终 `delta` 文本。
- `delta` 文本作为解释。
- `error` 显示重试按钮。

## 10. 后端给其他 AI 的扩展指南

### 10.1 新增标准 MacCMS 资源站

只改：

```text
cine_net_backend/services/resources/providers.yaml
```

新增：

```yaml
- id: demo
  name: 示例资源
  endpoint: https://example.com/api.php/provide/vod
```

不需要改 Agent，不需要改 Flutter。

### 10.2 新增非 MacCMS 资源站

例如 AGE、DM84、aafun、B站、网盘、本地电影。

做法：

1. 在 `services/resources/` 新建 Provider。
2. Provider 至少实现：
   - `search(keyword, limit)`
   - `detail(remote_id)`
   - `health()`
3. 返回统一模型：
   - `ResourceCandidate`
   - `MediaResourceDetail`
   - `PlayLine`
   - `Episode`
4. 注册到 `ProviderRegistry`。

Flutter 仍然消费 `/api/resources/*` 和 `microdesign.v1`。

### 10.3 新增 Catalog 资料源

例如 Letterboxd、Bangumi、IMDb 官方数据等。

做法：

1. 在 `services/catalog/` 新建 Provider。
2. 实现：
   - `hot(media_kind, limit)`
   - `search(query, media_kind, limit)`
   - 可选 `detail(source_id, media_kind)`
3. 返回统一 `CatalogMovie`。
4. 在 `services/catalog/registry.py` 注册 `kind`。
5. 在 `services/catalog/providers.yaml` 添加配置。

不要让 Flutter 直接对接这些第三方 API。

### 10.4 新增 Agent Tool

做法：

1. 在 `services/tools/` 新建文件。
2. 使用 `@tool` 声明工具。
3. 返回 JSON 字符串，`ensure_ascii=False`。
4. 在 `services/tools/registry.py` 加到 `get_agent_tools()`。
5. 如果 Tool 输出要给 Flutter 渲染，在 `services/agent/factory.py` 的 `_ATTACHMENT_TYPES` 注册附件类型。

### 10.5 新增图片生成

推荐后续作为 Tool 接入：

```text
generate_poster_background(movie, style)
-> 返回 image_url / asset_id
-> composer 写入 banner.data.image
```

不要让图片生成阻塞 Feed 首屏。可以先用豆瓣/TMDB 海报，图片生成完成后再刷新海报。

### 10.6 新增 RAG

推荐后续作为 Tool 接入：

```text
search_movie_knowledge(query)
```

Agent 可以用它增强推荐理由，但不要让 RAG 改写真实评分、播放地址、封面等字段。

## 11. 模型故障与降级

LLM 聚合站可能出现 `502 upstream_error`。当前处理：

- `ChatOpenAI` 配置 `max_retries=settings.llm_max_retries`。
- 持续失败时返回简短友好错误。
- REST/WS 不再把长堆栈直接暴露给前端。
- 普通 Feed、Catalog、Resource、Poster 接口不依赖 LLM。

前端原则：

```text
首页和播放器走确定性 REST。
聊天和复杂自然语言推荐走 Agent。
Agent 挂了，不影响普通浏览和播放。
```

Agent 提示词也已约束：

- 不得编造评分、简介、封面、资源站、播放 URL。
- Tool 字段为空时必须说“暂无”。
- 推荐理由可以生成，但事实字段必须来自 Tool。

## 12. 验收测试

PowerShell UTF-8：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:PYTHONIOENCODING = "utf-8"
cd cine_net_backend
```

离线测试：

```powershell
python -m unittest discover -s tests -v
Get-ChildItem -Recurse -Filter *.py | ForEach-Object { python -m py_compile $_.FullName }
git diff --check
```

资源真实联网：

```powershell
python scripts\smoke_resources.py
```

Catalog + Feed + Poster：

```powershell
python scripts\smoke_catalog.py
```

MicroDesign v1 主链，不依赖 LLM：

```powershell
python scripts\smoke_step3.py
```

Agent 调度与附件，需要 `.env` 中配置模型：

```powershell
python scripts\smoke_llm.py
python scripts\smoke_agent_step3.py
python scripts\smoke_ws_step3.py
```

也可以指定影片：

```powershell
python scripts\smoke_step3.py "流浪地球"
python scripts\smoke_agent_step3.py "流浪地球"
python scripts\smoke_ws_step3.py "流浪地球"
```

已经实测通过的《功夫熊猫》链路：

- Feed 返回 3 张帖子。
- 首张《功夫熊猫》评分 8.3。
- 首张命中 3 个可用资源站。
- `openPoster` 和 `resolveAndPlay` Action 存在。
- 互动海报风格 `warm`。
- `videoBar.action.data.play_url` 为真实 HTTP(S) `m3u8`。
- WebSocket 事件顺序为：

```text
started
-> tool_started
-> tool_finished
-> attachment
-> delta
-> done
```

## 13. 已知边界和后置能力

当前已经能支撑 Flutter 动态推荐和播放联调。

明确后置：

- B站公开视频搜索。
- B站登录态、会员资源、弹幕。
- AGE、DM84、aafun 等垂直资源站。
- 百度网盘、Alist 挂载。
- PC 本地电影解析与 HTTP Range 流式播放。
- AI 图片生成背景图。
- 用户偏好和历史 SQLite 持久化。
- F12 影视资讯采集。

这些能力后续都应作为 Provider 或 Tool 扩展，不推翻当前 `microdesign.v1` 协议。

## 14. 给接手者的最短路径

如果你是 Flutter 开发：

1. 调 `/api/health` 检查连接。
2. 调 `/api/feed/recommend?query=功夫熊猫` 做首页列表。
3. 实现 `posterRow`、`banner`、`rating`、`tagRow`、`heading`、`text`、`videoBar`。
4. 实现 `openPoster` 和 `resolveAndPlay`。
5. 聊天页接 `/ws/chat`，收到 `attachment` 就复用帖子卡片。

如果你是后端/AI 开发：

1. 不要绕过 `services/resources/` 和 `services/catalog/` 的统一模型。
2. 新资源做 Provider，新 Agent 能力做 Tool。
3. 事实字段必须来自 Tool。
4. 可视化输出必须走 `microdesign.v1` blocks/actions。
5. 扩展前先跑 `python scripts\smoke_step3.py`，扩展后再跑一遍。

## 15. 关键文件索引

| 文件 | 说明 |
|---|---|
| `cine_net_backend/config.py` | 环境变量、超时、缓存、Provider 配置路径 |
| `cine_net_backend/main.py` | FastAPI 入口和 router 挂载 |
| `cine_net_backend/routers/resources.py` | 完整播放资源 API |
| `cine_net_backend/routers/sources.py` | Flutter 兼容播放源 API |
| `cine_net_backend/routers/catalog.py` | 豆瓣 / TMDB 资料 API |
| `cine_net_backend/routers/feed.py` | 推荐 Feed API |
| `cine_net_backend/routers/poster.py` | MicroDesign 互动海报 API |
| `cine_net_backend/routers/agent.py` | Agent REST |
| `cine_net_backend/routers/chat.py` | Agent WebSocket |
| `cine_net_backend/services/resources/aggregator.py` | 多资源站并发聚合 |
| `cine_net_backend/services/resources/provider.py` | MacCMS Provider |
| `cine_net_backend/services/resources/playlist.py` | 播放列表解析 |
| `cine_net_backend/services/catalog/service.py` | Catalog 聚合与合并缓存 |
| `cine_net_backend/services/catalog/douban.py` | 豆瓣 Provider |
| `cine_net_backend/services/catalog/tmdb.py` | TMDB Provider |
| `cine_net_backend/services/recommendation/service.py` | Catalog + Resource 联合推荐 |
| `cine_net_backend/services/microdesign/models.py` | MicroDesign v1 模型 |
| `cine_net_backend/services/microdesign/composer.py` | blocks/actions 组合器 |
| `cine_net_backend/services/agent/factory.py` | LangChain Agent、附件、错误降级 |
| `cine_net_backend/services/tools/registry.py` | Agent Tool 注册中心 |
