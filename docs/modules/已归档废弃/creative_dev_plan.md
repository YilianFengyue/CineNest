# 成员 C 开发详细书（creative 模块 · F8 海报 / F9 对话 / F12 资讯）

> 本文是给 **Codex / AI 编码助手** 的逐任务施工图。每个任务标了**文件路径、做什么、关键签名、验收点**。
> 铁律见 [AGENTS.md](../../AGENTS.md) 与 [开发规范.md](../开发规范.md)：**只动 C 的目录**，中文注释，Python 标 `TODO(C)`，提交前 `flutter analyze` 零 error。

---

## 0. 模块边界与现状

**C 能改的目录（其余一律不碰，需要配合走 API 契约）：**
- 前端：`cine_nest_app/lib/pages/creative/`
- 后端：`cine_net_backend/routers/chat.py`、`routers/poster.py`、`services/news/`、`services/poster/`
- 共建区**只追加**（不改别人行）：`lib/http/api_constants.dart`（已含 C 的常量）、`lib/router/app_pages.dart` + `app_routes.dart`（追加 C 的 GetPage / 路由名）、`pages/main/main_app.dart`（对话 Tab 接页面）

**现状（已就绪，复用不重写）：**

| 资产 | 位置 | 状态 |
|------|------|------|
| 拼贴引擎数据原子 | `creative/models/content_block.dart` | ✅ `ContentBlock{type,data}` + 7 种 type + `fromJson` |
| 微组件库 | `creative/widgets/blocks.dart` | ✅ heading/text/tagRow/imageSwiper/videoBar/posterRow/rating |
| 区块分发器 | `creative/widgets/block_renderer.dart` | ✅ `BlockRenderer(blocks:, spacing:, onVideoTap:)` |
| 资讯条目模型 | `creative/models/news_item.dart` | ✅ `NewsItem.fromJson` 已按 `{id,title,source,published_at,blocks}` 解析 |
| 资讯 Tab UI | `creative/news/news_page.dart`、`news_card.dart` | ✅ 列表 + 下拉刷新 + 骨架屏 |
| 通用 HTTP | `lib/http/init.dart` | ✅ `Request().get(url, queryParameters:)` / `.post(url, data:)` → Dio `Response` |
| 路径常量 | `lib/http/api_constants.dart` | ✅ `ApiConstants.poster(id)` / `.news` / `.wsChat` |
| 后端 TMDB 服务 | `services/tmdb/` | ✅ `tmdb_service.{search,detail,popular,top_rated}` → `Movie`（B 的，**只调用不改**） |
| 后端推荐引擎 | `services/agent/engine.py` | ✅ `agent_engine.run_recommendation_flow(prompt)`（B 的，**只调用不改**） |

**待替换 / 删除：** `creative/services/bangumi_service.dart`、`creative/models/bangumi_subject.dart`（资讯换数据源后删）。

---

## 1. 架构主线（一句话）

```
后端 tmdb_service / agent_engine  ──→  C 的 routers(chat/poster) + services(news/poster)
        组装成 blocks JSON  ──→  Flutter Request()/WebSocket  ──→  BlockRenderer 纵向拼贴
```
**所有界面 = 一串 blocks 喂给 `BlockRenderer`。** 三个界面只是 blocks 来源不同：
- F12 资讯流：每条资讯 = 标题 + blocks（列表卡）
- F8 海报：点资讯/推荐卡 **进入**一部电影的 blocks 详情（竖向交互大海报，纯 Flutter 渲染）
- F9 对话：AI 气泡内嵌 blocks 推荐卡

> ⚠️ **绕开 TMDB 手机端连不上的坑**：TMDB 一律由**后端**去拉，手机只跟自己的 FastAPI 说话。前端不直连 `api.themoviedb.org` / `image.tmdb.org`（图片 URL 由后端拼好放进 blocks，手机只是显示，若图挂了 `CachedNetworkImage` 已有兜底）。

---

## 2. 数据契约（后端返回什么，前端按这个解析）—— 最重要，先定死

### 2.1 `GET /api/news` → `NewsItem[]`
```json
[
  {
    "id": "tmdb-693134",
    "title": "《沙丘2》",
    "source": "TMDB 热门",
    "published_at": "2026-05-01",
    "blocks": [
      {"type": "posterRow", "data": {
        "cover": "https://image.tmdb.org/t/p/w500/xxx.jpg",
        "score": 8.5,
        "summary": "保罗踏上复仇与救世之路……",
        "tags": ["科幻", "史诗"]
      }}
    ]
  }
]
```
- 前端模型 `NewsItem.fromJson` 已就绪，字段名严格用 `published_at`（下划线）。
- `blocks[].data` 是自由袋子，键名见 §2.4。

### 2.2 `GET /api/poster/{movie_id}?style=auto` → 海报 blocks
```json
{
  "movie_id": 693134,
  "style": "scifi",
  "blocks": [
    {"type": "banner",   "data": {"image": "<backdrop w780>", "title": "沙丘2", "subtitle": "Dune: Part Two · 2024"}},
    {"type": "rating",   "data": {"score": 8.5, "label": "TMDB"}},
    {"type": "tagRow",   "data": {"tags": ["科幻", "史诗", "冒险"]}},
    {"type": "heading",  "data": {"text": "推荐理由"}},
    {"type": "text",     "data": {"text": "维伦纽瓦把沙海拍成了宗教……"}},
    {"type": "text",     "data": {"text": "<overview 完整简介>"}}
  ]
}
```
- `style` 由后端按类型映射：`scifi`/`romance`/`action`/`auto`（第二步用于换配色，第一步可忽略）。
- **`banner` 是新增 block 类型**（见任务 C1-F1），其余类型已存在。
- 第二步可追加 `imageSwiper`（剧照）、`videoBar`（B站解说）。

### 2.3 `WS /ws/chat` 消息协议
**客户端 → 服务端**：纯文本（用户输入的一句话）。
**服务端 → 客户端**：JSON 帧，`type` 区分：
```json
{"type": "thinking"}
{"type": "delta", "content": "为你"}
{"type": "delta", "content": "找到这几部："}
{"type": "done",  "content": "为你找到这几部：",
  "cards": [
    {"movie_id": 157336, "title": "星际穿越",
     "blocks": [{"type":"posterRow","data":{"cover":"...","score":8.6,"summary":"...","tags":["科幻"]}}]}
  ]}
```
- `thinking`：显示「正在思考」气泡。
- `delta`：逐字/逐段追加到当前 AI 气泡（实现流式观感；第一步可把整句拆成几段假流式）。
- `done`：流结束，`cards[]` 渲染成可点推荐卡（`blocks` 走 `BlockRenderer`），点卡 → C 的海报页 `movie_id`。

### 2.4 block `data` 键名速查（与 `blocks.dart` 现有解析对齐）
| type | data 键 |
|------|---------|
| heading / text | `text` |
| tagRow | `tags: string[]` |
| imageSwiper | `urls: string[]` |
| videoBar | `title, cover, play_count?, duration?` |
| posterRow | `cover, score?, summary?, tags?` |
| rating | `score, label?` |
| **banner**（新增） | `image, title, subtitle?` |

---

## 🟢 第一步 · 基础闭环（不依赖 A/B，自给自足可演示）

> 目标：F8/F9/F12 三屏全亮，数据来自后端（TMDB 经 `tmdb_service`），手机直连本机后端即可演示。
> 验收态：资讯流出真电影、点进去看竖向 MicroDesign 海报、对话能聊出可点推荐卡。

### 后端

**C1-B1 · 资讯接口接真数据** — `routers/chat.py` + 新建 `services/news/builder.py`
- `services/news/builder.py`：写 `movies_to_news(movies: list[Movie]) -> list[dict]`，把 `Movie` 转成 §2.1 的 NewsItem dict（`posterRow` block：cover=`movie.poster_url`，score=`rating`，summary=`overview` 截 80 字，tags=`genres` 取前 3）。
- `routers/chat.py` 的 `get_news()`：改为 `movies = await tmdb_service.popular(page=1)` → `return movies_to_news(movies)`；`try/except` 失败回退一份本地 mock（保证不空）。
- 验收：`GET /api/news` 返回 ≥10 条带真实海报/评分的资讯。

**C1-B2 · 海报接口返 blocks** — `routers/poster.py` + 新建 `services/poster/builder.py`
- `services/poster/builder.py`：写 `movie_to_poster_blocks(movie: Movie, style: str) -> list[dict]`，产出 §2.2 的 blocks（banner 用 `backdrop_url`，无则 `poster_url`）。
- `routers/poster.py` 的 `get_poster()`：`movie = await tmdb_service.detail(movie_id)` → `return {"movie_id":..., "style":..., "blocks": movie_to_poster_blocks(movie, style)}`。
- ⚠️ **契约变更，需同步 B**：`/api/poster` 不再返回图片 URL，改返 blocks。B 的 feed 卡片缩略图请直接用 `movie.poster_url`，别依赖 `/api/poster`。（见 §5 同步项）
- 验收：`GET /api/poster/693134` 返回含 banner+rating+tagRow+text 的 blocks。

**C1-B3 · 对话 WebSocket 接推荐引擎** — `routers/chat.py` 的 `chat_ws`
- `from services.agent.engine import agent_engine`。
- 收到用户文本后：① 发 `{"type":"thinking"}`；② `result = await agent_engine.run_recommendation_flow(用户文本)`；③ 用 `result["raw_movies_context"]` + `result["ai_reasons"]`（按 `movie_id` join）拼 `cards[]`；④ 把开场白拆成几段发 `delta`；⑤ 发 `done` 带 `cards`。
- 卡片封面：`raw_movies_context` 无 poster，第一步对每个推荐 id 调 `await tmdb_service.detail(id)` 取 `poster_url`（≤5 部，可接受）；或与 B 协商在 `_minimize_movie_data` 加 poster（见 §5）。
- 验收：连上 `/ws/chat`，发「推荐像星际穿越的」，收到 thinking→delta→done，done 里 ≥1 张带海报+推荐语的 card。

### 前端

**C1-F1 · 新增 `banner` block 类型** — `creative/models/content_block.dart` + `widgets/blocks.dart` + `block_renderer.dart`
- `content_block.dart`：`ContentBlockType` 加 `banner`；加便捷构造 `ContentBlock.banner({image,title,subtitle})`。
- `blocks.dart`：新增 `BannerBlock`（大背景图 + 底部渐变 + 标题/副标题叠字，圆角，零阴影，走 `colorScheme`）。
- `block_renderer.dart`：`_render` 的 switch 加 `case ContentBlockType.banner: return BannerBlock(block);`。
- 验收：`flutter analyze` 零 error；banner 块能渲染。

**C1-F2 · 资讯换源到后端** — `creative/news/news_controller.dart`
- 删除对 `bangumi_service.dart` / `bangumi_subject.dart` 的依赖，改为 `Request().get(ApiConstants.news)`。
- 解析：`(res.data as List).map((e)=>NewsItem.fromJson(...))`；失败保留本地 `_mockNews` 兜底。
- 删除 `creative/services/bangumi_service.dart`、`creative/models/bangumi_subject.dart`。
- 验收：资讯 Tab 拉后端真数据，断网回退 mock 不空白。

**C1-F3 · F8 海报页（MicroDesign 竖向交互）** — 新建 `creative/poster/`
- `poster_service.dart`：`Future<List<ContentBlock>> fetchPoster(int movieId, {String style})` → `Request().get(ApiConstants.poster(movieId), queryParameters:{'style':style})` → 解析 `blocks`。
- `poster_controller.dart`（GetX）：持有 `RxList<ContentBlock> blocks`、`loading`，`onInit` 按传入 movieId 拉取。
- `poster_page.dart`：竖向 `CustomScrollView`/`ListView`，顶部 banner 通栏、下方各 block 加 `Padding` 拼贴（复用 `BlockRenderer`），整体走 tonal 表面 + 紧凑间距（对标 PiliPlus/Kazumi 详情页观感）。
- 路由：`app_routes.dart` 追加 `static const String creativePoster = '/creative-poster';`；`app_pages.dart` 追加 `GetPage(name: Routes.creativePoster, page: () => const PosterPage())`（movieId 经 `Get.arguments` 或 `Get.parameters` 传入）。
- 入口接线：`news_card.dart` 的 `onTap: () {}` → 改成跳海报页（从 NewsItem.id 解析 movieId）。
- 验收：点资讯卡 → 进入该电影竖向大海报，banner+评分+标签+理由+简介齐全，有设计感（非白底黑字）。

**C1-F4 · F9 对话页** — 新建 `creative/chat/`
- 依赖：若 `pubspec.yaml` 无 `web_socket_channel`，先添加（确认与 Flutter 3.35 / Dart 3.9 兼容）并 `flutter pub get`。
- `chat_message.dart`：模型 `{role(user/assistant), text, List<ChatCard> cards, bool thinking}`；`ChatCard{movieId, title, List<ContentBlock> blocks}`。
- `chat_service.dart`：用 `WebSocketChannel.connect(ws 基址 + ApiConstants.wsChat)` 建连（基址取 `ConnectionService.to.baseUrl`，把 `http://`→`ws://`）；暴露 `Stream` 与 `send(text)`。
- `chat_controller.dart`（GetX）：`RxList<ChatMessage> messages`；处理 `thinking/delta/done` 三种帧（delta 追加到末条 assistant 气泡，done 填 cards）。
- `chat_page.dart`：双气泡聊天 UI（用户右、AI 左）+ 底部输入框 + 发送；AI 气泡内 `cards` 用 `BlockRenderer` 渲染，点卡 → `Get.toNamed(Routes.creativePoster, arguments: card.movieId)`（B 的 `movieDetail` 就绪后可切换，见 §5）。
- 接线：`main_app.dart` 的 `_bodyFor` 把 `case 1` 接 `ChatPage()`（现在是占位）。
- 验收：对话 Tab 能发消息、出「正在思考」、流式出文字、出可点推荐卡、点卡跳海报页。

---

## 🔵 第二步 · 扩展（接更多源 + 难解析 tool + 打磨）

> 本质：**给 Agent 加工具**，把界面喂得更真更丰富。每个 tool 仿 `services/agent/tools.py` 的 schema + async 函数 + 注册三件套。

### 后端 Agent 工具扩展
- **C2-B1 资讯采集工具**：`services/news/` 加真资讯源（web 搜索 / 影视 RSS）→ Agent `collect_news` tool，`/api/news` 升级为真资讯（标题+摘要+来源链接，对应 F12 验收）。
- **C2-B2 按名搜片工具**：注册 `search_movie_by_name`（包 `tmdb_service.search`），让对话「像 XX 的电影」能精确落地。
- **C2-B3 解析类工具（⚠️ 属 A 的 video_engine 地盘，落地前与 A 同步，见 §5）**：
  - MacCMS 20 源直链解析（`vod_play_url` 按 `#`/`$` 拆集，见 [电影API资源.md](../电影API资源.md)）
  - B 站搜索/取流 + 弹幕、Alist 挂载网盘、PC 本地视频实时流（对应 F10/F11，加分项）
  - 这些作为 Agent 的「找片源」tool；解析逻辑建议放 A 的 `services/video_engine/`，C 的 Agent 只编排调用。

### 前端打磨
- **C2-F1 海报多风格**：`style` → 配色映射（科幻暗色 / 文艺暖色 / 动作高对比），banner 与表面色随 `style` 变（对应 F8「≥3 种风格」验收）。
- **C2-F2 真流式**：后端 LLM streaming 逐 token 推 `delta`；前端打字机效果。
- **C2-F3 推送提示组件**：有新资讯/新推荐时的角标/提示（设计书 C 的「推送通知提示组件」）。
- **C2-F4 海报页接 A 的播放**：banner / videoBar 的 `onTap` → 跳 A 的 `/player`（联调期）。

---

## 3. F8/F9/F12 验收对照（人工走查，对应需求书）

| 功能 | 验收点 | 第几步达成 |
|------|--------|-----------|
| F12 资讯 | Tab 有内容、≥5 条、每条含标题+摘要+来源 | 一步（mock/TMDB）→ 二步（真资讯+来源链接） |
| F8 海报 | 点进去看 MicroDesign 竖向海报、含名/分/理由/底图、排版美观非白底黑字 | 一步（单风格）→ 二步（≥3 风格自动匹配） |
| F9 对话 | 聊天 UI、回复含可点电影卡跳详情、有「思考中」或流式 | 一步（假流式+跳C海报）→ 二步（真流式+跳B详情） |

---

## 4. 提交前自检（每个任务完成后）
- `cd cine_nest_app && flutter analyze` 无 error。
- `cd cine_net_backend && python -m py_compile routers/chat.py routers/poster.py services/news/*.py services/poster/*.py` 无报错。
- commit：`[creative] 动词 + 内容`（如 `[creative] 资讯接口接 TMDB 真数据`）。
- 模块收尾时回填本目录的 `creative.md`（功能说明 + 验收结果 + 截图）。

---

## 5. 与 A / B 的同步项（碰到别人地盘，先打招呼）
1. **【B】`/api/poster` 契约变更**：从「返图片 URL」改为「返 blocks」。B 的 feed 卡片缩略图改用 `movie.poster_url`，不再依赖 `/api/poster`。
2. **【B】对话推荐卡跳转**：第一步跳 C 自己的海报页；B 的 `Routes.movieDetail` 页注册后，对话/资讯卡可切到跳 B 的详情。
3. **【B】（可选）`_minimize_movie_data` 加 poster 字段**：避免 C 在对话里为封面多调 `detail`。不改则 C 自己 enrich。
4. **【A】解析类工具落地位置**：MacCMS/B站/Alist/网盘/PC 本地的解析逻辑建议进 A 的 `services/video_engine/`，C 的 Agent 仅编排；若 C 先写，放 C 处需标注并后续移交。
</content>
</invoke>
