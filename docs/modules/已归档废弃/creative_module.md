# 成员 C · Creative 模块交接文档（F8 海报 / F9 对话 / F12 资讯 + 创意后端）

> 目的：新窗口/接手者读完即可测试、修 bug、继续完善，无需翻聊天记录。
> 配套：[creative_cards_v11.md](creative_cards_v11.md)（卡片字段契约）、[backend_agent.md](backend_agent.md)（后端总览 v1.2）、[api_contract.md](../api_contract.md)。
> 状态：前端 `flutter analyze` 零 issue；后端 `py_compile` 全过。后端 smoke 需在 venv 自跑。

---

## 0. 一句话

C 模块把后端 `microdesign.v1.1` 的 `blocks/actions` 渲染成三块界面：**F9 AI 对话**（flutter_chat_ui）、**F8 互动海报详情页**、**F12 资讯流**；并在后端补了 **AI 图片生成** + **Agent 生成资讯（带海报图）持久化**。
核心架构：**一切界面 = 一串 `blocks` 喂给 `BlockRenderer` 渲染**。

---

## 1. 架构主线

```
后端 (cine_net_backend)                         前端 (cine_nest_app/lib/pages/creative)
  Agent/Catalog/Resource/News/Images            ChatController / NewsController / PosterController
        └─ MicroDesign 组合 blocks ──REST/WS──▶  ContentBlock(JSON) ──▶ BlockRenderer ──▶ blocks.dart / cards.dart
```

- **数据原子**：`ContentBlock{type, data, action?}`（[models/content_block.dart](../../cine_nest_app/lib/pages/creative/models/content_block.dart)）
- **分发器**：`BlockRenderer`（[widgets/block_renderer.dart](../../cine_nest_app/lib/pages/creative/widgets/block_renderer.dart)）按 `type` 映射到 widget，未知类型静默跳过（前向兼容）
- **基础块**（[widgets/blocks.dart](../../cine_nest_app/lib/pages/creative/widgets/blocks.dart)）：banner/heading/text/tagRow/imageSwiper/videoBar/posterRow/rating
- **v1.1 富卡**（[widgets/cards.dart](../../cine_nest_app/lib/pages/creative/widgets/cards.dart)）：playableMovieCard/movieCarousel/reviewQuoteCard/sourceTraceCard/newsCard/mediaGallery/videoExplainCard
- **动作分发**：`handleCreativeAction`（[creative_actions.dart](../../cine_nest_app/lib/pages/creative/creative_actions.dart)）统一处理 `openPoster/openResourcePoster/resolveAndPlay`

---

## 2. 前端文件地图（`cine_nest_app/lib/pages/creative/`）

| 文件 | 作用 |
|---|---|
| `models/content_block.dart` | ContentBlock + MicroAction 数据模型；`listFrom()` 批量解析 |
| `widgets/block_renderer.dart` | 区块分发器（onAction / onVideoTap）|
| `widgets/blocks.dart` | 8 个基础块 widget |
| `widgets/cards.dart` | 7 个 v1.1 富交互卡 widget |
| `creative_actions.dart` | 统一 action 分发：跳海报 / 调 `/api/play/resolve` |
| **F9 对话** | |
| `chat/chat_page.dart` | Chat 主页：装配 flutter_chat_ui + builders + 头像 + 图片气泡 + 空态 + AppBar 操作 |
| `chat/chat_controller.dart` | GetX：WS 事件→消息编排、模型列表、直连推荐、本地持久化 |
| `chat/services/chat_ws_service.dart` | WebSocket 连接/重连/解析；模型选项模型 |
| `chat/services/chat_store.dart` | 多会话本地持久化（Hive localCache） |
| `chat/models/agent_event.dart` | 后端 7 种 WS 事件帧模型 |
| `chat/models/chat_meta.dart` | CustomMessage metadata 键约定 + 作者 id |
| `chat/widgets/agent_status_card.dart` | 思考动画 + 来源 chip 状态条 |
| `chat/widgets/tool_source.dart` / `tool_chip.dart` | 工具→来源映射 + chip |
| `chat/widgets/typing_dots.dart` | 三点思考动画 |
| `chat/widgets/attachment_card.dart` | 渲染 4 类附件：recommendation_feed/microdesign_poster/interactive_cards/news_feed |
| `chat/widgets/chat_composer.dart` | 自定义输入区：模型选择 + 图片上传(多模态) + 发送 |
| `chat/widgets/recommend_sheet.dart` | 「为你推荐」sheet：快捷提问 + 直连推荐 + 卡片预览入口 |
| **F8 海报** | |
| `poster/poster_page.dart` | SliverAppBar 头图 + blocks 拼贴 + 底部播放栏 + 导出长图分享 |
| `poster/poster_controller.dart` | 解析 PosterSpec（mock/真后端通用），style 配色 |
| `poster/poster_export_view.dart` | 离屏长图渲染视图（自带 Theme/MediaQuery） |
| `poster/poster_mock.dart` | 一整页富卡 PosterSpec 假数据 |
| **F12 资讯** | |
| `news/news_page.dart` | `/api/news` 卡片流 + 下拉刷新 + 骨架 + 空错态 + 「AI 资讯」FAB |
| `news/news_controller.dart` | 拉 `/api/news`、生成资讯 `POST /api/news/generate` |
| **预览（设计走查）** | |
| `preview/card_gallery_page.dart` + `card_mock.dart` | 7 张卡 mock 画廊（对话页空态有入口） |

**改动的共建文件：**
- [http/api_constants.dart](../../cine_nest_app/lib/http/api_constants.dart)：补齐 v1.2 路径（posterCatalog/news/newsGenerate/agentModels/chatSessions/microdesignSchema/playResolve/uploads/asset）
- [utils/media_url.dart](../../cine_nest_app/lib/utils/media_url.dart)（新建）：相对资源 URL 按 `Pref.baseUrl` 补全
- [utils/storage_pref.dart](../../cine_nest_app/lib/utils/storage_pref.dart) / `storage_key.dart`：`chatModelId` 偏好；**`dynamicColor` 默认改为 `true`**（系统动态取色）
- [router/app_pages.dart](../../cine_nest_app/lib/router/app_pages.dart) / `app_routes.dart`：注册 `Routes.creativePoster = '/creative-poster'`
- [pages/main/main_app.dart](../../cine_nest_app/lib/pages/main/main_app.dart)：对话 Tab(case 1)接 `ChatPage`；资讯 Tab(case 2)接 `NewsPage`；AppBar 注入 `chatAppBarActions`
- `pubspec.yaml`：新增 `flutter_chat_ui/flutter_chat_core/flyer_chat_text_message/web_socket_channel/provider/file_picker/image_picker/screenshot/share_plus`

---

## 3. 数据契约（前端消费什么）

**协议 `microdesign.v1.1`**。详细字段见 [creative_cards_v11.md](creative_cards_v11.md) 与 [backend_agent.md](backend_agent.md) §6/§7。

- **WS `/ws/chat`** 发 `{message, thread_id, model, attachments[]}`；收事件 `started/tool_started/tool_finished/attachment/delta/done/error`。
- **附件 4 类**（`attachment.data.type` + `.payload`）：
  - `recommendation_feed` → `payload.posts[]`
  - `microdesign_poster` → PosterSpec
  - `interactive_cards` → `payload.cards[]`（一串 block）
  - `news_feed` → `payload.items[].blocks[]`
- **Action 3 种**：`openPoster`(catalog_provider_id/source_id)、`openResourcePoster`(provider_id/remote_id)、`resolveAndPlay`(provider_id/remote_id[/play_url])。
- **REST**：`/api/feed/recommend`、`/api/poster/catalog/{p}/{s}`、`/api/news`、`/api/news/generate`、`/api/agent/models`、`/api/play/resolve`、`/api/uploads`。

---

## 4. 各功能讲解 + 关键技术点

### 4.1 F9 AI 对话
- 库：**flutter_chat_ui v2**（`Chat` + `Builders` + `InMemoryChatController`）+ `flyer_chat_text_message`（Markdown 气泡）。
- **事件→消息映射**（`ChatController._onEvent`）：`started`→插状态条；`tool_started`→状态条加来源 chip；`attachment`→插 `CustomMessage`(kind=附件类型)；`delta`→累加助手 `TextMessage`（用 `updateMessage`，因后端是分段全量非逐 token）；`done`→收尾；`error`→错误条+重试。
- **头像**：自写 `_ChatAvatar`（chat_page），网络头像失败→渐变圆+图标兜底。⚠️ 默认 URL 是 Pinterest（`i.pinimg.com`），**国内被墙拉不到**，所以走兜底；想用真头像换可达地址或本地 asset。
- **图片上传多模态**：composer 选图→`/api/uploads`拿 `asset_id`→随 `attachments` 发给 Agent；本地先插图片气泡展示。
- **模型选择**：拉 `/api/agent/models`（id: default/fast/deep），失败回退 `kChatModels`。
- **持久化**：前端本地 Hive（`chat_store.dart`，多会话）；后端 WS 也自动落 SQLite（两套并存，目前前端用本地）。
- ⚠️ **命名冲突**：`flutter_chat_core` 也有 `ChatController`，在 chat_page 用 `hide ChatController`；composer 里 `FormData/MultipartFile` 在 dio 和 get 都有，`import get hide FormData, MultipartFile`。

### 4.2 F8 互动海报
- `PosterController` 解析 PosterSpec：抽 banner 当头图、rating 当评分、其余 blocks 进正文。**mock 与真后端结构一致**，`_fetchReal` 打 `/api/poster/catalog/{p}/{s}`；无参数(资讯/对话未带 catalog id)走 `posterMockSpec()`。
- 页面：SliverAppBar 模糊头图 + 海报 + 评分胶囊（颜色随 `style` neon/contrast/warm）→ BlockRenderer 正文 → 底部「立即播放」。
- **导出长图分享**：`screenshot` 的 `captureFromLongWidget` 离屏渲染 `poster_export_view`（自带 Theme/MediaQuery）→ PNG → `share_plus` 系统分享。⚠️ 离屏渲染网络图依赖缓存+delay，偶发图未加载属已知限制。

### 4.3 F12 资讯
- `NewsController` 拉 `/api/news`，每条 item 的 `blocks`（newsCard+mediaGallery）直接 BlockRenderer 渲染，newsCard 自带点击→openPoster→海报页。
- **「AI 资讯」FAB**：输入片名→`POST /api/news/generate`→后端查资料+AI 生图+持久化→刷新列表置顶。
- ⚠️ **慢请求超时**：生图十几~几十秒，该 POST 单独设 `receiveTimeout 180s / sendTimeout 60s`（Dio 默认仅 10s，否则报 `HTTP/2 forcefully terminated`）。

### 4.4 后端 AI 图片生成（`cine_net_backend/services/images/`）
- `generate_image(prompt, size)`→调 `gpt-image-2 @ https://api.gpt.ge/v1/images/generations`（key 复用 `LLM_API_KEY`，base 固定 gpt.ge；不同站填 `IMAGE_API_KEY`）→下载存为 asset→返回 `/api/assets/{id}` 相对 URL。
- **失败一律返回 None 降级**到 TMDB/豆瓣海报，不阻塞主流程。
- 前端 `mediaUrl()` 把 `/api/assets/..` 相对地址按 `Pref.baseUrl` 补成绝对 URL（换 IP 无需改）。

### 4.5 后端 Agent 生成资讯（`services/news/service.py`）
- `generate_news_for_query(query)`：Catalog 搜片→AI 生海报图→组 newsCard+mediaGallery→存 `news_items`→返回 NewsItem。
- 暴露：REST `POST /api/news/generate`、Agent 工具 `generate_movie_news`（聊天说"给X生成资讯"触发，产 `news_feed` 附件 + 落库）。
- `build_news_feed`（热门 10 条）**不生图**（避免慢），只有单条生成才生图。

---

## 5. 后端改动清单（cine_net_backend）

| 文件 | 改动 |
|---|---|
| `config.py` | 加 `image_enabled/image_api_key/image_base_url(=gpt.ge)/image_model(gpt-image-2)/image_timeout` |
| `services/images/{__init__,service}.py` | **新建** 图片生成服务 |
| `services/assets/service.py` + `__init__.py` | 加 `save_bytes()`（存任意字节为 asset） |
| `services/news/service.py` + `__init__.py` | 加 `generate_news_for_query()` |
| `routers/news.py` | 加 `POST /api/news/generate` |
| `services/tools/news.py` | 加 `generate_movie_news` 工具 |
| `services/tools/registry.py` | 注册 `generate_movie_news` |
| `services/agent/factory.py` | `_ATTACHMENT_TYPES` 加 `generate_movie_news→news_feed`；SYSTEM_PROMPT 加生成资讯/优先富卡指引 |

---

## 6. 跑起来 / 验收

```bash
# 后端
cd cine_net_backend
# .env 填 LLM_API_KEY / LLM_BASE_URL (+TMDB 可选)；图片复用 LLM key
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 前端
cd cine_nest_app && flutter pub get && flutter run   # 大写 R 热重启
```

⚠️ **后端地址**：[api_constants.dart:11](../../cine_nest_app/lib/http/api_constants.dart#L11) `defaultBaseUrl` 当前是临时联调 IP `http://100.64.122.30:8000`，**换网络要改这一行**（F7 设置页是 A 的活，未做前只能改默认值）。真机用 PC 局域网/热点 IP，PC `uvicorn --host 0.0.0.0`。

**验收路径：**
1. 资讯 Tab →「AI 资讯」FAB 输入"星际穿越"→ 十几秒后出带 AI 海报图的资讯卡 → 点进完整海报 → 右上导出长图。
2. 对话 Tab → "推荐几部科幻片"→ 富媒体可播放卡；"帮我生成《沙丘2》的资讯特辑"→ 资讯卡且资讯页可见。
3. 对话发图片(+号)、切模型、卡片「立即播放」出解析地址（复制）。
4. 对话空态「预览交互卡片」→ 7 张卡设计走查（纯 mock，不依赖后端）。

---

## 7. 已知问题 / 待办（给接手者）

- **resolveAndPlay**：当前调 `/api/play/resolve` 后弹出地址+复制；A 的 `/player` 就绪后，把 [creative_actions.dart](../../cine_nest_app/lib/pages/creative/creative_actions.dart) 的 TODO 一行改成 `Get.toNamed(Routes.player, arguments: desc)`。
- **资讯→海报真数据**：资讯卡 openPoster 的 catalog id 来自后端 newsCard.action；mock/无 id 时海报页走 mock。确认后端 news 的 action 带全 `catalog_provider_id/source_id`。
- **图片生成依赖**：`LLM_API_KEY` 须在 api.gpt.ge 有效；否则单独 `IMAGE_API_KEY`，或 `IMAGE_ENABLED=false` 关掉用 TMDB 图。生图慢可换 `IMAGE_MODEL=gpt-image-1`。
- **头像**：Pinterest 被墙→走兜底图标；要真头像换可达 URL / 本地 asset。
- **后端 smoke**：本仓库无 venv，仅 `py_compile` 过；请在自己 venv 跑 `python scripts\smoke_p0_p4.py` 验证生图/生成资讯。
- **聊天历史双写**：前端 Hive + 后端 SQLite 并存，目前前端读本地；如需跨设备，切到 `/api/chat/sessions`。
- **导出长图**：离屏网络图偶发未加载（缓存竞态），可加大 `delay` 或先预热缓存。

---

## 8. 关键约定（别踩坑）
- 事实字段（评分/封面/播放 URL）必须来自后端 Tool，**Agent 不编造**；卡片"编排+文案"可由 Agent 填。
- 新增 block 类型：前端 `ContentBlockType` 加枚举 + `cards.dart`/`blocks.dart` 加 widget + `block_renderer.dart` 加 case；后端 `microdesign/composer.py` 产出对应 `type`。**前端先定字段，后端跟**。
- UI 一律 `Theme.of(context).colorScheme` + tonal + 零阴影，禁硬编码颜色（评分星 amber、图片蒙层黑白除外）。
