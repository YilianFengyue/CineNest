# CineNest 渐进重构与播放器产品化计划

> 目标读者：后续接手开发的同学、AI 编码助手、模块负责人。  
> 目标状态：CineNest 先成为一个高可用、体验完整的影视聚合播放器，再在此基础上保留并增强 Agent 能力。  
> 执行原则：每次只推进一个可验收任务包；涉及现有代码修改时先按 `AGENTS.md` 说明文件、函数、改动理由并等确认。

---

## 0. 总结论

当前 CineNest 的 AI / Agent 能力已经相对强，但基础影视 App 能力边界不清：

- 搜索、详情、历史、收藏、播放源、封面加载大量依赖后端 FastAPI。
- Flutter 客户端更像远程 UI 壳，而不是一个独立、流畅、可离线保底的影视播放器。
- 播放入口分散在 Feed、Player、Creative action 中，缺统一播放会话模型。
- 文档与当前代码已有不一致，例如 `docs/modules/player.md` 写有 `player_page.dart` 和 `/player`，但当前 `cine_nest_app/lib/pages/player/views/player_page.dart` 不存在，`app_pages.dart` 也未注册 `Routes.player`。

重构方向：

```text
Flutter 客户端 = 完整影视聚合播放器产品
FastAPI 后端 = PC Agent 增强侧车
```

四个大步骤的硬边界：

- Step 1 完成后，播放器和后端彻底解耦；Flutter 自己就能搜索、选源、解析并播放。
- Step 2 完成后，不是增加花哨功能，而是让播放“更多、更稳”：源更多、封面更稳、详情更完整、匹配更可靠。
- Step 3 完成后，播放器从可用变成产品化：交互、历史、收藏、设置、下载、离线等常见影视 App 能力完整。
- Step 4 默认不是新功能开发阶段，而是 Agent 无损耗回归验收阶段；只有验收发现 Agent 推荐、资讯、海报、B站/网盘入口被前面重构影响时，才补必要的兼容修复。

也就是说：

- 基础影视体验回到 Flutter：搜索、源聚合、详情展示、封面缓存、播放、历史、收藏、下载、设置。
- 后端继续保留 Agent：智能推荐、资讯、海报、B站/网盘/PC 本地库/GitHub 资源库等增强能力。
- 后端可以提供同步和重解析，但不能成为基础功能的单点依赖。

---

## 1. 参考仓库调研结论

### 1.1 MoonTV：影视聚合产品参考

参考位置：

- `CodeReference/MoonTV/README.md`
- `CodeReference/MoonTV/config.json`
- `CodeReference/MoonTV/src/lib/downstream.ts`
- `CodeReference/MoonTV/src/app/api/search/route.ts`
- `CodeReference/MoonTV/src/app/api/detail/route.ts`
- `CodeReference/MoonTV/src/app/play/page.tsx`
- `CodeReference/MoonTV/src/lib/db.client.ts`

MoonTV 的核心价值：

- 多源配置集中在 `config.json`，内置多个 MacCMS 资源站。
- `/api/search` 并发搜索全部启用源，并做结果合并。
- `/api/detail` 用 `source + id` 拉资源站详情。
- 播放记录、收藏、搜索历史有本地缓存和服务端同步两套能力。
- 图片代理支持长缓存，避免第三方封面直接加载失败。
- 播放页支持源优选、测速、换源、选集、跳片头片尾、HLS 播放和去广告实验功能。

对 CineNest 的启发：

- 影视聚合不是 Agent 的附属功能，而是一个稳定的产品底座。
- `source + id` 是播放资源的基础主键，不应只存 TMDB id。
- 历史和收藏要记录到具体播放源、集数、进度、封面、搜索标题。
- 图片代理和本地缓存必须纳入基础体验，不然封面容易丢、卡、白。

### 1.2 Kazumi：Flutter 播放器与规则源参考

参考位置：

- `CodeReference/Kazumi/README.md`
- `CodeReference/Kazumi/lib/plugins/plugins.dart`
- `CodeReference/Kazumi/lib/plugins/plugins_controller.dart`
- `CodeReference/Kazumi/lib/services/video_source/video_source_service.dart`
- `CodeReference/Kazumi/lib/services/video_source/webview_video_source_service.dart`
- `CodeReference/Kazumi/lib/pages/video/video_controller.dart`
- `CodeReference/Kazumi/lib/pages/player/player_controller.dart`
- `CodeReference/Kazumi/lib/repositories/history_repository.dart`
- `CodeReference/Kazumi/lib/repositories/collect_crud_repository.dart`
- `CodeReference/Kazumi/lib/services/download/download_manager.dart`
- `CodeReference/Kazumi/lib/utils/m3u8_parser.dart`

Kazumi 的核心价值：

- Flutter 端有自己的规则源系统，使用 HTML + XPath 解析搜索结果和播放列表。
- WebView 负责捕获真实视频 URL，适合处理部分前端动态站点。
- 播放链路清晰：详情/集数选择 -> 视频源解析 -> PlayerController 播放。
- Hive 本地管理历史、收藏、下载，不依赖远程服务才能使用。
- 下载管理完整，支持 m3u8 master/media playlist、key、分片、暂停/恢复、并发、空间检查、本地 playlist。
- 播放器产品化程度高，支持音量/亮度、倍速、外部播放器、投屏、超分、弹幕等。

对 CineNest 的启发：

- Flutter 端应建立自己的 `SourceRepository`、`SourceResolver`、`PlayerSession`、`HistoryRepository`、`DownloadManager`。
- Python 后端可以做增强解析，但 Flutter 不能完全依赖后端才能播放。
- 下载管理要按模块做，不应临时在播放器页面塞按钮。

### 1.3 PiliPlus：Flutter 基建和交互标准参考

参考位置：

- `CodeReference/PiliPlus/README.md`
- `CodeReference/PiliPlus/lib/http/loading_state.dart`
- `CodeReference/PiliPlus/lib/http/init.dart`
- `CodeReference/PiliPlus/lib/utils/storage.dart`
- `CodeReference/PiliPlus/lib/utils/cache_manager.dart`
- `CodeReference/PiliPlus/lib/plugin/pl_player/controller.dart`
- `CodeReference/PiliPlus/lib/plugin/pl_player/view/view.dart`
- `CodeReference/PiliPlus/lib/services/download/download_service.dart`

PiliPlus 的核心价值：

- GetX 路由、Dio、Hive、LoadingState、设置项体系可继续作为 CineNest 基建风格。
- 播放器交互标准高：手势亮度/音量、双击快进、长按倍速、PIP、字幕、画质、音质、全屏方向、进度记忆。
- 设置页面和下载页面成熟，适合拆分播放设置、下载设置、缓存管理。
- B站相关能力丰富，但 CineNest 应只借鉴可用模式，避免直接带回账号、WBI、gRPC 等强 B 站耦合逻辑。

对 CineNest 的启发：

- 继续保留 GetX + Dio + Hive + LoadingState 的基建。
- 播放器交互要向 PiliPlus 靠拢，不停留在 `media_kit` Demo。
- 设置页要变成真实功能入口，而不是一组占位页。

---

## 2. 新架构边界

### 2.1 Flutter 客户端负责

Flutter 是用户真正使用的影视 App，必须保证基础体验独立可用：

- 本地影视聚合器：资源站列表、启用/禁用、排序、搜索、详情、播放源解析。
- 本地资料缓存：搜索结果、详情、海报、背景图、演员、评分、简介。
- 播放器：统一播放会话、换源、选集、WebView 降级、进度恢复、错误重试。
- 本地历史：访问历史、播放历史、每集进度、最后播放源。
- 本地收藏：影片收藏、源收藏、海报收藏。
- 下载管理：m3u8/mp4 下载、队列、暂停恢复、本地播放。
- 设置：播放设置、下载设置、源规则管理、缓存清理、PC 后端连接。

### 2.2 FastAPI 后端负责

后端是 PC 算力中心和 Agent 增强层：

- Agent 对话、智能推荐、推荐理由、资讯、MicroDesign 海报。
- PC 重解析：B站直链、网盘解析、PC 本地影片库、复杂反爬源。
- 资源源下发：给 Flutter 提供可更新 provider/rule 列表。
- 同步服务：历史、收藏、偏好、观看进度跨设备同步。
- 代理服务：图片代理、CORS 代理、失败源兜底。

### 2.3 不能再混淆的边界

不要再让这些功能硬依赖 Agent：

- 普通搜索。
- 普通详情页。
- 播放源列表。
- 播放历史。
- 收藏。
- 封面加载。
- 播放器入口。

Agent 可以读这些数据并增强它们，但不能取代它们。

### 2.4 Flutter UI 和组件选型原则

UI 参考 Kazumi 和 PiliPlus，但不要直接复制它们的业务耦合代码。

执行原则：

- 优先使用 Flutter 官方 Material 组件、Material 3 组件和成熟 pub 包。
- 能用官方组件解决的，不手写复杂交互控件。
- 能用成熟 pub 包解决的，不从零造轮子；新增依赖前确认 Flutter 3.35 / Dart 3.9 兼容。
- 播放器交互多参考 Kazumi / PiliPlus：手势、倍速、选集、换源、设置、下载页密度和信息层级。
- 基础页面不要做花哨营销感 UI，影视 App 要优先：封面清晰、信息密度合理、按钮位置稳定、错误态明确。
- 封面卡、详情 Header、播放控制栏、下载列表、历史列表优先做成可复用 Widget，避免每页各写一套样式。

建议优先考虑的组件方向：

- 图片：`cached_network_image` + 自定义 `flutter_cache_manager`。
- 列表骨架和加载态：Material `CircularProgressIndicator` / `LinearProgressIndicator`，必要时引入轻量 skeleton 包。
- 路由与状态：继续沿用 GetX，但页面内部控件尽量保持 Material 标准手感。
- 播放器：继续基于 `media_kit`，UI 层参考 PiliPlus/Kazumi 的交互布局。
- 下载通知、后台任务：先查成熟插件可用性，再决定是否分平台实现。

---

## 3. 四阶段渐进开发总表

| 阶段 | 名称 | 核心目标 | 完成标志 |
|---|---|---|---|
| Step 1 | 拆后端，把播放和本地聚合回归客户端 | Flutter 与后端播放链路彻底解耦，客户端自己能播 | 关闭 PC 后端/Agent 后，仍能搜索、选源、解析、播放、记录历史 |
| Step 2 | 修源头，补齐豆瓣/TMDB/详情资料库 | 让可播放内容更多、更稳，资料和封面更完整 | 同一搜索词能返回更多有效源，详情页不空、不乱、不全靠 fallback |
| Step 3 | 播放器产品化和常见影视 App 功能补全，含下载管理 | 接近 Kazumi/PiliPlus 的播放和本地体验 | 播放、历史、收藏、下载、设置形成完整闭环 |
| Step 4 | Agent 无损耗回归验收 | 确认 AI 推荐、资讯、海报、B站、网盘等增强能力没有被重构破坏 | Agent 功能保持可用，并通过统一媒体模型进入详情/播放 |

---

## 4. Step 1：拆后端，把影视播放回归客户端以及本地影视聚合器

### 4.1 目标

把 CineNest 从“Flutter 远程请求后端播放”改成“Flutter 自己就是影视聚合播放器”。

必须做到：

- 没有 LLM、没有 Agent、甚至 PC 后端不可用时，Flutter 仍然可以完成基础影视流程。
- 播放器不再依赖后端返回播放地址才能启动；后端解析只作为增强兜底。
- 本地资源聚合器至少能独立完成：搜索、详情拉取、集数解析、播放 URL 解析或 WebView 降级。
- 后端 `/api/resources/*`、`/api/sources/*` 保留，但变成增强/同步/兜底通道。
- 播放入口统一，Feed、详情、Creative 卡片都进入同一个播放会话。

### 4.2 当前要先确认的问题

当前 checkout 已发现：

- `cine_nest_app/lib/pages/player/views/player_page.dart` 不存在。
- `cine_nest_app/lib/router/app_pages.dart` 未注册 `Routes.player`。
- `source_picker_page.dart` 同时承担搜索、解析、播放、换源职责，过重。
- `creative_actions.dart` 的 `resolveAndPlay` 当前只弹出地址，不进入播放器。

因此第一步不是继续扩展 Agent，而是先恢复播放器主链路。

### 4.3 任务包 1.1：定义客户端播放资源模型

建议新增/调整 Flutter 模型：

```text
cine_nest_app/lib/models/media_item.dart
cine_nest_app/lib/models/media_source.dart
cine_nest_app/lib/models/play_episode.dart
cine_nest_app/lib/models/play_session.dart
```

建议模型职责：

- `MediaItem`：影视条目，统一 TMDB/豆瓣/资源站结果。
- `MediaSource`：某资源站的一条资源，使用 `providerId + remoteId` 做主键。
- `PlayEpisode`：集数、标题、播放页 URL、直链 URL、时长、清晰度。
- `PlaySession`：播放器入口参数，包含标题、封面、当前源、当前集、headers、fallback web url。

关键字段建议：

```text
MediaItem:
- id: string
- title: string
- originalTitle: string?
- year: string?
- posterUrl: string?
- backdropUrl: string?
- overview: string?
- genres: list<string>
- rating: double?
- sourceRefs: list<MediaSourceRef>

MediaSource:
- providerId: string
- providerName: string
- remoteId: string
- title: string
- coverUrl: string?
- year: string?
- category: string?
- remarks: string?
- detailUrl: string?
- episodes: list<PlayEpisode>

PlayEpisode:
- index: int
- title: string
- pageUrl: string?
- playUrl: string?
- quality: string?
- headers: map<string,string>
- fallbackWebUrl: string?
```

验收：

- 现有 `VideoSource` 能兼容迁移到新模型，或提供 adapter。
- `source_picker_page.dart` 不再直接把 `VideoSource` 当唯一播放数据结构。
- 后续 Agent 的 `resolveAndPlay` 能构造同一套 `PlaySession`。

### 4.4 任务包 1.2：建立 Flutter 本地资源仓库

参考：

- MoonTV `config.json`
- MoonTV `downstream.ts`
- Kazumi `plugins_controller.dart`

建议新增目录：

```text
cine_nest_app/lib/pages/player/sources/
  source_provider.dart
  source_registry.dart
  maccms_provider.dart
  source_search_service.dart
  source_detail_service.dart
  source_health_service.dart
```

第一阶段先做 MacCMS JSON，不急着做 Kazumi XPath 规则。

启动种子策略：

- v1 必须走“打包种子 + 后端异步增量”的双轨方案。
- 打包种子放在 Flutter assets，例如 `cine_nest_app/assets/providers/maccms_seed.json`。
- 第一版只内置 5-8 个稳定 MacCMS 源，先保证上线可用，不等待动态规则系统完成。
- App 启动时先加载本地 assets 种子，保证离线和后端不可用时也有源。
- 后端可用时，再异步拉取 `/api/resources/providers` 或后续专用规则接口做增量更新。
- 拉取到的远程规则写入 Hive，下一次启动优先使用“本地用户配置 + 最新远程缓存 + assets 种子”合并结果。
- 远程规则更新失败不得阻塞启动，也不得清空用户已有可用源。

合并优先级：

```text
用户手动禁用/排序 > Hive 远程缓存 > assets 打包种子 > 后端临时兜底
```

功能点：

- 内置一批 MacCMS Provider，优先复用后端 `services/resources/providers.yaml` 和 MoonTV `config.json` 中稳定源。
- 本地启用/禁用 Provider。
- 本地排序。
- 并发搜索多个源。
- 单源失败不影响整体搜索。
- 合并重复结果。
- 记录 trace：哪个源成功、耗时、结果数、错误。

验收：

- 关闭 PC 后端，只用 Flutter 搜索“肖申克的救赎”，能返回至少一个资源站结果或明确的空态。
- 单个源超时不会卡住整个搜索。
- 搜索结果显示来源、年份、封面、清晰度/备注。
- 设置页能看到资源站列表并启用/禁用。

### 4.5 任务包 1.3：统一播放入口

建议新增：

```text
cine_nest_app/lib/pages/player/views/player_page.dart
cine_nest_app/lib/pages/player/controllers/player_controller.dart
cine_nest_app/lib/pages/player/controllers/play_session_controller.dart
```

职责划分：

- `SourcePickerPage`：只负责搜索和选源，不直接承担完整播放器职责。
- `PlayerPage`：正式播放页面。
- `PlayerController`：只管 media_kit 播放状态、进度、错误、倍速、音量、全屏。
- `PlaySessionController`：管理当前影片、源、集数、换源、WebView 降级。

默认 UX 决策：

- 默认采用 Kazumi 流：用户点击播放后自动选第一个最可信可用源，直接进入 `/player`。
- 不默认让用户先面对一页源列表；源选择是播放器里的辅助能力，不是播放前置门槛。
- 播放器内提供“换源”入口，建议放在全屏控制层右下角或更多菜单中。
- 自动选源失败时，再弹出 `SourcePickerPage` 让用户手动选择。
- 如果搜索结果来自 MoonTV 式多源页，也允许用户主动点“更多源”进入 `SourcePickerPage`。

自动选源评分建议：

```text
有直链/可解析 > 最近成功播放过 > 当前影片标题和年份匹配高 > 清晰度/备注更可信 > 源健康耗时更短 > 用户排序更靠前
```

路由统一：

```text
Routes.player = /player
Routes.sourcePicker = /source-picker
Routes.webviewPlayer = /webview-player
```

所有播放入口都走：

```text
Get.toNamed(Routes.player, arguments: PlaySession)
```

涉及入口：

- `pages/feed/detail/detail_view.dart`
- `pages/player/views/source_picker_page.dart`
- `pages/player/views/source_debug_panel.dart`
- `pages/creative/creative_actions.dart`
- `pages/creative/widgets/cards.dart`
- `pages/creative/chat/widgets/attachment_card.dart`

验收：

- 详情页点播放进入 `/player`。
- 源选择页点源进入 `/player`。
- Creative 卡片 `resolveAndPlay` 解析后进入 `/player`，不再只复制地址。
- 播放失败可重试、换源、WebView 降级。

### 4.6 任务包 1.4：本地历史和收藏先落 Flutter

参考：

- Kazumi `history_repository.dart`
- Kazumi `collect_crud_repository.dart`
- MoonTV `PlayRecord` / `Favorite`

建议新增：

```text
cine_nest_app/lib/repositories/history_repository.dart
cine_nest_app/lib/repositories/favorite_repository.dart
cine_nest_app/lib/models/watch_history.dart
cine_nest_app/lib/models/favorite_item.dart
```

历史至少记录：

- `mediaId`
- `title`
- `posterUrl`
- `providerId`
- `providerName`
- `remoteId`
- `episodeIndex`
- `episodeTitle`
- `playPositionMs`
- `durationMs`
- `updatedAt`
- `searchTitle`

收藏至少记录：

- `mediaId`
- `title`
- `posterUrl`
- `year`
- `providerId`
- `providerName`
- `remoteId`
- `totalEpisodes`
- `savedAt`

验收：

- 播放 30 秒退出，再进入能提示继续播放或自动恢复进度。
- 历史页不依赖后端也能展示。
- 收藏/取消收藏立即生效。
- 后端不可用时历史、收藏不丢。

### 4.7 任务包 1.5：图片基础稳定性提前做

图片不要等到 Step 2 才开始处理。Step 1 验收时，用户第一眼看到的是搜索结果和详情封面；封面大面积丢失或卡顿，会让“播放器解耦完成”看起来仍然像半成品。

技术选型：

- Flutter 端使用 `cached_network_image`。
- 缓存管理使用自定义 `flutter_cache_manager` 配置。
- 统一封装 `ResilientNetworkImage`，页面不直接散落 `Image.network`。
- 豆瓣图片默认不在前端硬加 Referer；需要 Referer 的图片走后端图片代理。
- TMDB 图片优先直连 + 本地缓存，失败再走后端代理。
- 资源站图片先直连 + 本地缓存；检测到跨域/防盗链/超时后再走代理。

建议新增：

```text
cine_nest_app/lib/services/image_resolver.dart
cine_nest_app/lib/common/widgets/resilient_network_image.dart
cine_nest_app/lib/common/image/cinenest_cache_manager.dart
```

缓存建议：

```text
posterCache:
- maxObjects: 800
- stalePeriod: 30 days
- maxFileSize: 2-5 MB 单图软限制

backdropCache:
- maxObjects: 300
- stalePeriod: 14 days

avatarCache:
- maxObjects: 500
- stalePeriod: 30 days
```

验收：

- 搜索结果快速滚动时，封面不出现大片空白。
- 已加载封面在断网后仍能显示缓存。
- 豆瓣图片通过代理能展示，且后端代理带合适缓存头。
- 图片失败显示统一占位图，不撑坏卡片布局。

### 4.8 Step 1 后端接口归宿清单

Step 1 结束时必须把“客户端主链路”和“后端增强链路”切清楚。不要让旧接口继续模糊地承担基础播放职责。

| Endpoint | 当前用途 | Step 1 后归宿 | 处理动作 |
|---|---|---|---|
| `GET /api/sources/search` | 旧后端搜索入口 | 废弃为客户端主链路 | Flutter 不再调用；确认无调用后拆分 `bilibili` 能力并移除旧搜索入口 |
| `GET /api/sources/parse` | 后端解析播放源 | 保留为兜底 | 仅当前端 MacCMS/WebView 解析失败或 Agent 增强源需要 PC 解析时调用 |
| `GET /api/resources/providers` | 后端资源源列表 | 保留为异步增量 | App 启动后异步拉取，不阻塞本地 seed 启动 |
| `GET /api/resources/search` | 后端资源聚合搜索 | 降级为调试/兜底 | Flutter 本地聚合为主；后端搜索只用于诊断、兜底或 PC 增强源 |
| `GET /api/resources/{provider_id}/{remote_id}` | 后端资源详情 | 保留为兜底详情 | 本地详情失败时调用，不能作为普通详情主路径 |
| `GET /api/catalog/search` / `GET /api/catalog/hot` | TMDB/豆瓣资料 | 保留只读增强 | 用于资料补全、榜单、推荐，不再决定能不能播放 |
| `GET /api/catalog/{provider_id}/{source_id}` | 资料详情 | 保留只读增强 | 作为 metadata 详情源，不替代资源站 `source+id` 主键 |
| `GET /api/movie/{movie_id}` / `GET /api/discovery` | 旧 Feed 资料入口 | 兼容只读，后续合并 | Step 2 统一到 metadata/catalog 服务后再逐步废弃 |
| `GET /api/history` / `POST /api/history/record` | 后端历史 | 降级为同步接口 | 本地 Hive 为主；后端只做多设备同步和 Agent 上下文 |
| `GET /api/collections` / `POST /api/collections/toggle` | 后端收藏 | 降级为同步接口 | 本地 Hive 为主；后端只做多设备同步 |
| `GET /api/play/resolve` | 后端播放描述 | 保留为 Agent/PC 兜底 | 不再是基础播放主入口；Creative/Agent action 也要转成统一 `PlaySession` |
| `GET /api/proxy/image` / `GET /api/image-proxy` | 图片代理 | 保留并加强 | 负责豆瓣 Referer、防盗链、缓存头和失败兜底 |
| `/ws/chat` / `/api/agent/*` | Agent 能力 | 保留增强层 | 不参与基础搜索、历史、收藏、播放器启动 |
| `/api/news/*` / `/api/poster/*` / `/api/microdesign/*` | 资讯、海报、MicroDesign | 保留增强层 | action 统一跳详情或 `/player`，不走旧播放链路 |

完成判定：

- Flutter 代码里不能再把 `/api/sources/search`、`/api/resources/search`、`/api/play/resolve` 当普通播放主路径。
- 旧接口保留时必须在文档中标注“兜底/同步/增强/兼容”，不能继续写成主能力。
- 真正删除接口前，先跑全局 `rg` 确认 Flutter、脚本、测试和 Agent 没有硬依赖。

### 4.9 Step 1 最终验收

必走流程：

1. 关闭后端。
2. 打开 App。
3. 搜索“星际穿越”或“肖申克的救赎”。
4. 看到本地聚合结果。
5. 进入详情/源列表。
6. 点击播放。
7. 能播放 m3u8/mp4 或进入 WebView 降级。
8. 退出后历史里有记录。
9. 收藏能立即保存。

完成判定：

- 这是“架构解耦完成”的验收，不是简单做一个播放器页面。
- 如果任一基础播放流程还必须请求 FastAPI 才能继续，Step 1 视为未完成。
- FastAPI 可以继续提供更强解析、同步和代理，但 Flutter 必须有本地可用的完整主链路。

交付物：

- 更新 `docs/api_contract.md`：标清客户端本地能力和后端增强接口。
- 新增/更新 `docs/modules/player.md`：必须与当前文件真实一致。
- 新增 `docs/modules/client_resource_aggregator.md`。

---

## 5. Step 2：修源头，提升豆瓣/TMDB 解析稳定性，补齐详情和资料库

### 5.1 目标

解决“封面卡、详情空、资料不完整、豆瓣/TMDB 配置混乱”的问题。

这一阶段的核心不是重构播放器，而是让 Step 1 已经独立可用的播放器“播放更多、更稳”。

最终效果：

- 搜索结果有稳定封面。
- 详情页有完整简介、评分、年份、类型、导演、主演、背景图。
- 资源站结果和资料库结果能匹配。
- 豆瓣/TMDB 失败时有明确降级，不白屏、不乱编。
- 多源搜索的有效播放率提升，坏源、空源、假源有清晰过滤和降级。

### 5.2 当前问题

当前后端存在配置分裂：

- `config.py` 写了 `tmdb_read_access_token` 和 `tmdb_api_key`。
- `services/catalog/tmdb.py` 支持 Read Access Token。
- 但旧 `services/tmdb/client.py` 读取的是 `settings.tmdb_api_key` 并放进 Bearer。
- `routers/feed.py` 多处用 `settings.tmdb_api_key` 判断是否启用 TMDB。

风险：

- 用户按文档填了 `TMDB_READ_ACCESS_TOKEN`，但旧 Feed/Discovery/Detail 仍走 fallback。
- 资料库不稳定，推荐看起来像假数据。

### 5.3 任务包 2.1：统一资料源接口

建议新增统一抽象：

```text
cine_net_backend/services/metadata/
  models.py
  provider.py
  tmdb_provider.py
  douban_provider.py
  service.py
```

或者在现有 `services/catalog/` 上扩展，但不要继续维护两套 TMDB。

统一接口：

```text
search(query, media_kind, limit) -> list<MediaMetadata>
detail(provider_id, source_id, media_kind) -> MediaMetadata
match(resource_title, year?) -> MediaMetadata?
```

资料优先级：

```text
TMDB = 主资料库
豆瓣 = 中文榜单、评分、热门分类、中文标题/别名辅助
MoonTV 模式 = 豆瓣列表页、图片代理、source+id 记录方式、播放页源匹配策略参考
资源站 = 播放源事实来源和 fallback 基础信息
```

判断：

- TMDB 信息更结构化，适合做主资料：海报、背景、演员、类型、简介、相似推荐。
- 豆瓣在中文语境、热门榜单、评分感知上更有价值，适合辅助，不宜取代 TMDB 主模型。
- MoonTV 对豆瓣的用法值得借鉴：豆瓣页做发现入口，卡片带 `douban_id`，点击后再映射到真实资源站 `source+id`。
- 播放是否可用必须以资源站和本地解析结果为准，不能因为 TMDB/豆瓣有资料就认为可播放。

验收：

- `TMDB_READ_ACCESS_TOKEN` 和 `TMDB_API_KEY` 都能正确工作。
- `.env` 只需要一种 TMDB 配置也能跑。
- `feed.py`、`catalog.py`、`poster.py` 不再各自绕开统一资料服务。

### 5.4 任务包 2.2：封面和图片稳定性

Step 1 已经要求完成基础图片稳定性；Step 2 在此基础上做“更完整、更智能”的图片资料链路。

参考：

- MoonTV `image-proxy/route.ts`
- PiliPlus `CacheManager`
- 当前 `main.py /api/proxy/image`

要做：

- Flutter 所有远程图片统一走 `ImageResolver`，旧 `mediaUrl()` 只能作为兼容层。
- 对豆瓣/TMDB/资源站封面做来源判断。
- 优先本地缓存，其次直连，失败再走后端图片代理。
- 后端图片代理增加缓存头和来源 headers，豆瓣默认带 `Referer: https://movie.douban.com/`。
- TMDB 图片尺寸要统一选择：列表用 `w342/w500`，详情背景用 `w780/original`，避免列表直接拉原图。
- 资源站图片要记录失败次数，连续失败的域名优先走代理。
- 占位图要可接受，不能灰块大片空白。

建议新增：

```text
cine_nest_app/lib/services/image_resolver.dart
cine_nest_app/lib/common/widgets/resilient_network_image.dart
cine_nest_app/lib/common/image/cinenest_cache_manager.dart
```

缓存策略：

```text
列表封面：30 天 TTL，最多 800 张
详情背景：14 天 TTL，最多 300 张
演员头像：30 天 TTL，最多 500 张
失败 URL：短期负缓存 10-30 分钟，避免反复请求坏图
```

验收：

- 快速滚动搜索结果，封面不大面积丢失。
- 换网络后已加载封面能从缓存显示。
- 豆瓣图片需要 Referer 时能通过代理展示。
- TMDB 列表封面不会直接加载超大原图。
- 资源站坏图不会每次刷新都重复打满请求。
- 图片失败有统一占位，不出现布局跳动。

### 5.5 任务包 2.3：详情页资料补齐

详情页建议拆成区块：

- 顶部海报/背景图。
- 基础信息：标题、原名、年份、地区、类型、片长。
- 评分：TMDB、豆瓣可选。
- 简介。
- 导演/主演。
- 播放源列表。
- 相关 B站视频/解说。
- 收藏、喜欢、不感兴趣。
- 相似推荐。

Flutter 建议文件：

```text
cine_nest_app/lib/pages/feed/detail/
  detail_view.dart
  detail_controller.dart
  widgets/metadata_header.dart
  widgets/cast_section.dart
  widgets/source_section.dart
  widgets/related_section.dart
```

验收：

- 打开 “星际穿越” 详情页，至少显示标题、年份、类型、评分、简介、海报。
- 有资料源时显示导演/主演。
- 无资料源时不白屏，显示资源站简介和封面。
- 播放源列表与详情资料区分清楚。

### 5.6 任务包 2.4：资源站和资料库匹配

匹配逻辑：

- 标题标准化：去空格、标点、书名号、大小写。
- 年份强匹配：有年份时优先年份接近。
- 别名匹配：中文名、原名、英文名、资源站标题。
- 置信度评分：exact title + year > alias > fuzzy。

建议新增：

```text
cine_nest_app/lib/utils/title_matcher.dart
cine_net_backend/services/metadata/matcher.py
```

验收：

- 搜索 “Interstellar” 能匹配 “星际穿越”。
- 搜索 “The Shawshank Redemption” 能匹配 “肖申克的救赎”。
- 同名不同年份不应轻易合并。
- 资源站结果不被错误合并成完全不同电影。

### 5.7 Step 2 最终验收

必走流程：

1. 分别搜索中文名、英文名。
2. 检查搜索结果封面。
3. 进入详情页。
4. 检查简介、评分、类型、导演、演员、背景图。
5. 断开 TMDB 或豆瓣，确认 fallback 仍能展示资源站基础信息。
6. 观察后端日志，不应出现“填了 token 仍完全 fallback”的情况。

完成判定：

- 同样的影片搜索词，Step 2 之后应比 Step 1 返回更多可用源或更稳定可播源。
- 封面、背景、演员、简介、评分的缺失率要明显下降。
- 如果只是 UI 显示更好看，但源仍大量不可播、资料仍大量 fallback，Step 2 视为未完成。

交付物：

- 更新 `.env.example` 或配置说明。
- 更新 `docs/api_contract.md` 中资料模型。
- 新增/更新 `docs/modules/metadata_catalog.md`。

---

## 6. Step 3：播放器产品化、完整影视 App 功能补全、下载管理

### 6.1 目标

让 CineNest 的基础体验接近 Kazumi/PiliPlus：

- 播放稳定。
- 操作完整。
- 历史、收藏、搜索历史、设置、下载形成闭环。
- 用户能把它当真实影视 App 使用，而不是课设 Demo。

这一阶段默认不再改变 Step 1 的架构边界，也不把基础功能重新塞回后端；重点是把“能播”打磨成“好用、耐用、细节完整”。

### 6.2 任务包 3.1：播放器控制器产品化

参考：

- Kazumi `player_controller.dart`
- PiliPlus `pl_player/controller.dart`
- PiliPlus `pl_player/view/view.dart`

播放器必须支持：

- 播放/暂停。
- 进度条拖动。
- 全屏/退出全屏。
- 倍速：0.5 / 0.75 / 1 / 1.25 / 1.5 / 2。
- 音量调节。
- 亮度调节。
- 错误重试。
- 换源。
- 选集。
- 加载态。
- 自动保存进度。

第二批增强：

- 双击左/右快退快进。
- 长按倍速。
- 手势横滑 seek。
- 左侧亮度、右侧音量。
- 画面比例：contain / cover / fill / fitWidth / fitHeight。
- 锁定控制栏。
- 下一集自动播放。
- 后台播放或 PIP，按平台逐步做。

验收：

- 同一部电影/电视剧能换源播放。
- 播放失败时不白屏，有重试和 WebView。
- 全屏下仍可选集、换源、倍速。
- 退出再进入恢复上次进度。

### 6.3 任务包 3.2：播放设置

设置项建议：

- 默认倍速。
- 快进/快退秒数。
- 自动播放下一集。
- 默认画面比例。
- 进入播放是否自动横屏。
- 是否长按倍速。
- 是否显示源测速。
- 是否启用 WebView 降级。
- 是否记忆播放进度。
- 是否无痕播放。

建议文件：

```text
cine_nest_app/lib/pages/settings/playback_settings_page.dart
cine_nest_app/lib/utils/storage_key.dart
cine_nest_app/lib/utils/storage_pref.dart
```

验收：

- 修改默认倍速后，下一次播放生效。
- 修改快进秒数后，播放器手势/按钮生效。
- 无痕播放时不写历史。

### 6.4 任务包 3.3：搜索历史和搜索页体验

参考：

- MoonTV `searchhistory`
- Kazumi `search_history_repository.dart`
- PiliPlus 搜索页、热搜、搜索历史

功能点：

- 搜索历史本地存储。
- 删除单条历史。
- 清空全部历史。
- 搜索建议或默认搜索词。
- 搜索结果按影视/剧集/来源筛选。
- 搜索结果支持“只看有播放源”。

验收：

- 搜索后返回搜索页能看到历史。
- 删除历史立即生效。
- 搜索结果能按来源筛选。

### 6.5 任务包 3.4：历史页产品化

历史分两类：

- 浏览历史：打开过详情。
- 播放历史：播放到某集某秒。

播放历史卡片展示：

- 封面。
- 标题。
- 来源。
- 上次集数。
- 进度条。
- 上次观看时间。
- 继续播放按钮。

验收：

- 播放 30 秒后历史页出现进度。
- 点击继续播放直接进入对应集数和进度。
- 删除单条、清空全部可用。

### 6.6 任务包 3.5：收藏页产品化

收藏类型：

- 影片收藏。
- 播放源收藏。
- Creative 海报收藏可以保留在 C 模块，但应与影片收藏有跳转关系。

功能点：

- 收藏/取消收藏。
- 收藏页搜索。
- 按时间排序。
- 按来源筛选。
- 收藏详情入口。

验收：

- 在详情页收藏，收藏页立即出现。
- 在收藏页取消，详情页状态同步。
- 后端不可用时仍可收藏。

### 6.7 任务包 3.6：视频源规则管理

参考：

- MoonTV 管理后台 source 配置。
- Kazumi 插件管理。

第一阶段：

- MacCMS 源列表管理。
- 启用/禁用。
- 排序。
- 健康检查。
- 手动新增 Provider：id、name、endpoint。

第二阶段：

- 导入/导出规则。
- 从后端/GitHub 更新规则源。
- 支持 Kazumi XPath 风格 WebView 规则。

验收：

- 禁用某个源后搜索不再请求它。
- 新增一个 MacCMS endpoint 后能参与搜索。
- 健康检查显示成功/失败/耗时。

### 6.8 任务包 3.7：下载管理

参考：

- Kazumi `download_manager.dart`
- Kazumi `m3u8_parser.dart`
- PiliPlus `download_service.dart`

下载管理不能压成一个小任务。Kazumi 的下载能力本身就是一个完整子系统，CineNest 要分三段做，避免拖垮 Step 3。

必须做成独立模块：

```text
cine_nest_app/lib/pages/download/
cine_nest_app/lib/services/download/
cine_nest_app/lib/repositories/download_repository.dart
cine_nest_app/lib/models/download_task.dart
```

下载模型：

- 下载记录。
- 下载集数。
- 下载状态：pending / downloading / paused / completed / failed / cancelled。
- 下载进度。
- 下载速度。
- 本地文件路径。
- 错误信息。

### 6.8.1 任务包 3.7a：mp4 单文件下载 + 队列管理

目标：

- 先把下载页、下载模型、队列状态、文件落地跑通。
- 只支持 mp4/直链单文件，不碰 m3u8。
- 为后续 m3u8 和后台下载打基础。

功能点：

- mp4 直接下载。
- 下载队列。
- 下载进度。
- 暂停、恢复、取消。
- 删除文件。
- 本地播放。

验收：

- 对 demo mp4 能下载并本地播放。
- 同时添加多个任务，队列状态正确。
- 暂停/恢复/取消能改变状态，App 重启后任务列表仍存在。
- 删除下载后文件实际删除。

预估：

- 1 周。

### 6.8.2 任务包 3.7b：m3u8 解析 + 分段并发 + 本地 playlist

目标：

- 支持常见 m3u8 资源离线。
- 参考 Kazumi `m3u8_parser.dart`，但按 CineNest 模型重写，不直接混入 Kazumi 业务逻辑。

功能点：

- master playlist 解析。
- variant 选择。
- media playlist 解析。
- segment URL 归一化。
- AES key 下载。
- segment 并发下载。
- 失败 segment 重试。
- 生成本地 playlist。
- 本地 m3u8 播放。

验收：

- 对一个公开 m3u8 能下载分片并生成本地 playlist。
- segment 下载失败有重试和错误记录。
- 已下载内容在无网络时可播放。
- m3u8 下载和 mp4 下载共用同一任务列表。

预估：

- 1-2 周。

### 6.8.3 任务包 3.7c：后台下载 + 通知 + 续传

目标：

- 把下载从“页面开着能跑”提升到“产品可用”。
- 这一步涉及平台差异，必须谨慎选插件和做降级。

功能点：

- 后台下载。
- 下载完成通知。
- 断点续传。
- 网络变化处理。
- 仅 Wi-Fi 下载。
- 存储空间检查。
- App 被杀后恢复任务状态。

下载设置：

- 下载目录。
- 同时下载集数。
- 分片并发数。
- 仅 Wi-Fi 下载。
- 存储空间检查。
- 下载完成通知。

验收：

- 后台下载不会因为离开下载页立即停止。
- 通知能显示下载状态。
- 网络断开后任务进入等待或失败可恢复状态。
- App 重启后能继续未完成任务。

预估：

- 1 周。

### 6.9 Step 3 最终验收

必走流程：

1. 搜索影片。
2. 进入详情。
3. 收藏影片。
4. 播放并拖动进度。
5. 全屏下调倍速、换源、选集。
6. 退出后历史页继续播放。
7. 添加下载任务。
8. 暂停、恢复、完成、本地播放。
9. 设置页修改播放参数并验证生效。

完成判定：

- 播放器体验应达到“可以连续追一部剧”的水准，而不是只验证单次播放成功。
- 历史、收藏、下载、设置必须围绕同一套 `MediaItem / MediaSource / PlaySession` 工作。
- 如果下载、收藏、历史只是孤立页面，不能回到详情和播放器，Step 3 视为未完成。

交付物：

- `docs/modules/player.md`
- `docs/modules/source_aggregator.md`
- `docs/modules/history_collection.md`
- `docs/modules/download.md`

---

## 7. Step 4：Agent 无损耗回归验收

### 7.1 目标

Step 4 默认不是继续大规模写新功能，而是验收前面三步重构后，当前 Agent 强项没有被破坏：

- Chat。
- Agent 推荐。
- MicroDesign 海报。
- 资讯。
- 图片/附件上传。
- 后端工具调用。
- B站、网盘、PC 本地库等已有或预留增强入口。

验收原则：

- Agent 只做增强，不接管基础影视功能。
- 基础搜索、详情、播放、历史、收藏、下载不依赖 Agent。
- Agent 推荐出的影视内容，最终仍进入 Step 1-3 建好的统一详情页和播放器。
- 如果验收全通过，Step 4 可以不写代码，只补验收记录和模块文档。
- 如果验收发现断点，只做兼容修复，不重新设计基础播放链路。

### 7.2 验收项 4.1：Agent 基础对话不受影响

验收内容：

- `/ws/chat` 仍能连接。
- 普通影视问答仍有回复。
- 附件/图片相关能力不报错。
- Agent 失败时 Flutter 有错误态，不影响基础影视播放。

验收步骤：

1. 启动后端和 Flutter。
2. 打开 Chat。
3. 输入“推荐几部适合周末看的科幻电影”。
4. 确认能返回推荐文本或卡片。
5. 临时断开 LLM 配置，确认基础搜索/播放仍可用。

需要写代码的条件：

- Chat 无法连接。
- Agent 错误导致 App 全局崩溃。
- Agent 返回结构与 Flutter 当前模型不兼容，卡片无法渲染。

### 7.3 验收项 4.2：Agent 推荐结果能进入统一影视主链路

Agent 推荐不能返回一套孤立卡片。

期望结果应该能映射到：

- `MediaItem`
- `MediaSourceRef`
- `PlayAction`
- `PosterSpec`

Flutter 收到后：

- 可进入详情。
- 可收藏。
- 可播放。
- 可加入历史。

验收：

- Chat 推荐卡片点击后进入同一个详情页。
- Chat 的“立即播放”进入同一个 `/player`。
- Agent 推荐的影片能被收藏和记录历史。

需要写代码的条件：

- 推荐卡片只能展示，不能进入详情。
- “立即播放”还在走旧的后端专用播放入口。
- 推荐产生的影片不能被收藏或写入历史。

### 7.4 验收项 4.3：Agent 能读取客户端影视上下文

Flutter 可以把本地上下文提供给 Agent：

- 最近观看。
- 收藏。
- 喜欢/不喜欢。
- 搜索历史。
- 播放失败源。
- 当前影片详情。

建议新增接口：

```text
POST /api/agent/context/sync
GET /api/agent/context/summary
```

或者先直接在 `/api/agent/invoke` 的 attachments/context 里带摘要。

验收：

- 用户问“根据我最近看的推荐”，Agent 能用本地历史。
- 用户问“不想看恐怖片”，偏好能影响推荐。
- Agent 不编造播放源，播放源仍来自资源聚合器。

需要写代码的条件：

- Agent 完全不知道用户历史、收藏、偏好。
- 前三步引入本地历史后，后端推荐质量明显下降。
- 需要把本地上下文用最小 payload 同步给 Agent。

### 7.5 验收项 4.4：B站增强入口不受影响

B站放到后端增强层更合理：

- B站搜索。
- 解说/影评/混剪聚合。
- BV 号解析。
- 有 cookie 时尝试直链。
- 无 cookie 时 WebView 降级。

Flutter 只接收统一 `MediaSource` 或 `PlaySession`。

验收：

- 搜索“星际穿越 解说”能返回 B站结果。
- 可直链时进入播放器。
- 不可直链时进入 WebView。
- 不影响普通资源站播放。

需要写代码的条件：

- 原有 B站入口被路由调整破坏。
- B站结果不能转成统一 `MediaSource` 或 `PlaySession`。
- B站播放失败影响普通资源站播放。

### 7.6 验收项 4.5：网盘与 PC 本地库入口不受影响

后端适合做：

- 百度网盘/夸克/阿里链接解析。
- Alist 挂载。
- PC 本地影视目录扫描。
- 局域网文件服务。

统一返回：

```text
MediaSource:
- providerId = baidu_netdisk / quark / alist / pc_local
- remoteId
- title
- episodes/files
- playable url 或 pending resolve action
```

验收：

- 输入一个分享链接，能展示文件树。
- 视频文件能进入播放器或给出明确不可播原因。
- PC 本地目录能被手机浏览并播放。

需要写代码的条件：

- 网盘/PC 本地库入口仍返回旧结构，Flutter 无法展示。
- 视频文件无法进入统一播放器。
- 失败态不明确，用户不知道是权限、格式还是解析失败。

### 7.7 验收项 4.6：资讯和 MicroDesign 保持稳定

当前 C 模块能力保留：

- `/ws/chat`
- `/api/news`
- `/api/news/generate`
- `/api/poster/catalog/...`
- `/api/microdesign/schema`

需要调整的是 action：

- `resolveAndPlay` 不再弹复制地址。
- 所有播放 action 走统一 `PlaySession`。
- `openPoster` 和 `openResourcePoster` 不影响基础详情页。

验收：

- 资讯 Tab 仍能展示。
- 生成资讯仍能落库。
- 海报页仍能打开。
- 海报页立即播放进入正式播放器。

需要写代码的条件：

- 资讯 Tab 无法展示或生成。
- 海报页路由失效。
- 海报页播放 action 还停留在复制链接或旧播放入口。

### 7.8 Step 4 最终验收

必走流程：

1. Chat 输入“推荐几部适合我最近口味的科幻片”。
2. Agent 读取历史/收藏/偏好。
3. 返回可点击卡片。
4. 点击详情进入普通详情页。
5. 点击播放进入正式播放器。
6. 资讯 Tab 生成一条影视资讯。
7. 海报页打开并能播放。
8. 断开 LLM 后，基础搜索/播放/历史/收藏仍可用。

完成判定：

- 如果上述流程全部通过，Step 4 可以只提交验收文档，不需要新增代码。
- 如果 Agent 有断点，只修断点和适配层，不允许把 Step 1-3 已经客户端化的基础播放能力重新放回 Agent。
- Step 4 完成后，Agent 应该是“增强体验更聪明”，而不是“基础功能又依赖后端”。

---

## 8. 每一步通用验收标准

每个任务包完成时必须写：

- 改了哪些文件。
- 新增了哪些模型/接口/路由。
- 如何运行。
- 如何人工验收。
- 当前限制。
- 下一步建议。

每个模块文档位置：

```text
docs/modules/<模块名>.md
```

提交前检查：

```powershell
cd cine_nest_app
flutter analyze
```

```powershell
cd cine_net_backend
python -m py_compile <目标文件>
```

涉及接口契约变化时，必须同步：

- `docs/api_contract.md`
- Flutter `lib/models/`
- 后端 `models/schemas.py` 或对应新模型文件

---

## 9. 推荐开发排期

### 第一轮：恢复基础播放闭环

优先级最高。

任务：

- 统一播放模型。
- 恢复 `/player` 页面。
- 详情页/源页/Creative action 全部进入播放器。
- 打包 5-8 个 MacCMS seed provider。
- 默认自动选源进入播放器，播放器内换源。
- 本地播放历史。
- 本地收藏。
- 基础图片缓存和代理兜底。
- 标注 Step 1 后端接口归宿。

验收：

- 后端不可用时，至少 seed 源/demo 源/本地源可播放。
- 后端可用时，资源站源可播放。
- 退出后历史和收藏可用。
- 搜索结果封面不大面积丢失。
- Flutter 不再把后端搜索和后端 resolve 当基础播放主链路。

### 第二轮：本地聚合器和资料库

任务：

- Flutter MacCMS provider registry。
- Flutter 本地搜索/详情。
- 资料库统一：TMDB 主，豆瓣辅助，资源站 fallback。
- 图片缓存/代理增强。
- 标题、年份、别名匹配。

验收：

- 搜索结果更快、更稳定。
- 详情资料完整。
- 封面不大面积丢失。
- 同一影片可用源更多，坏源降级更明确。

### 第三轮：播放器交互和下载

任务：

- 播放器手势/倍速/全屏/选集/换源完善。
- 播放设置。
- 下载管理 3.7a：mp4 单文件下载和队列。
- 下载管理 3.7b：m3u8 分片下载和本地 playlist。
- 下载管理 3.7c：后台下载、通知、续传。

验收：

- 用户能用它连续看一部剧。
- 下载后能离线播放。
- 设置、历史、收藏、下载都能回到同一个详情页和播放器。

### 第四轮：Agent 无损耗回归验收

任务：

- 验收 Agent 基础对话。
- 验收 Agent 推荐结果能进入统一媒体模型。
- 验收 B站、网盘、PC 本地库增强入口不受影响。
- 验收资讯、海报、MicroDesign 不受影响。
- 只有验收失败时才做最小兼容修复。

验收：

- Agent 功能不退化。
- 基础播放不依赖 Agent。
- Agent 推荐能进入普通详情页和正式播放器。
- 验收全通过时只写验收文档，不新增代码。

---

## 10. 最终验收目标

最终 CineNest 应达到：

### 播放和基础影视体验接近 Kazumi

- 多源搜索。
- 源规则可更新。
- 选集和换源流畅。
- 播放器手势完整。
- 历史/收藏/下载本地稳定。
- m3u8/mp4/WebView 降级可用。
- 下载可离线播放。

### 资源源头和聚合体验接近 MoonTV

- 多个资源站并发聚合。
- 搜索结果合并去重。
- 详情页资料完整。
- 图片代理/缓存稳定。
- 播放记录、收藏、搜索历史体验完整。
- 源管理清晰。

### Flutter 工程风格继续保持 PiliPlus 基建优势

- GetX 路由清楚。
- Dio/LoadingState 统一。
- Hive 本地存储稳定。
- 设置项可导出/迁移。
- UI 状态和错误态完整。
- UI 尽量使用官方 Material / Material 3 组件和成熟 pub 包。
- 播放器、下载、设置、历史页交互参考 Kazumi / PiliPlus 的成熟布局。

### 资料、海报和资讯体验参考 MoonTV，但主资料链路保持清晰

- TMDB 做主资料库，承担结构化详情、海报、背景、演员、类型、相似推荐。
- 豆瓣做中文发现、热门分类、评分和中文别名辅助。
- MoonTV 的豆瓣页、图片代理、播放记录、收藏、`source+id` 设计作为实现参考。
- 资讯和 MicroDesign 保留现有 Agent 能力，但其 action 必须能跳普通详情页和正式播放器。
- 海报卡片不应该成为孤立内容，必须能关联 `MediaItem`、`MediaSourceRef` 或搜索关键词。

### Agent 功能保留并增强

- AI 推荐不失效。
- Chat 不失效。
- MicroDesign 海报不失效。
- 资讯不失效。
- B站/网盘/PC 本地库成为增强能力。
- Agent 使用本地历史和收藏做更智能推荐。

---

## 11. 下一步建议

下一次开发建议从 Step 1 开始，并且只做一个明确任务包：

```text
Step 1 / 任务包 1.1 + 1.3：
定义统一 PlaySession 模型，恢复正式 /player 页面，
让详情页、源选择页、Creative resolveAndPlay 都能进入同一个播放器。
```

这是后续所有工作的地基。播放器入口不统一，源聚合、历史、收藏、下载和 Agent 播放 action 都会继续分裂。
