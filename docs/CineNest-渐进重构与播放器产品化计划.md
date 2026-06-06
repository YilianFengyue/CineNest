# CineNest 重构计划：Kazumi 产品骨架 + MoonTV 影视源内核

> 目标读者：后续接手开发的同学、AI 编码助手、模块负责人。  
> 当前基线：`562095f docs:更新重构文档`。  
> 执行原则：`CodeReference/` 只读；先照参考仓库拆结构和验收，不再临时发明播放链路。

---

## 0. 这次为什么要重写计划

上一版 Step 1 的失败点已经坐实：

- 只写了一个粗糙 MacCMS API 原型，没有抄到 Kazumi 的产品骨架。
- 搜索阶段没有验证结果可播，导致点进去才转圈、报错、失败。
- Home 仍然像后端 Feed 壳，后端关掉就空或半残。
- 封面、错误态、源健康度、播放器启动时序都不是产品级。
- WebView 被当成播放成功兜底，实际体验很差。

所以这次重构不再说“参考 Kazumi / MoonTV”，而是明确：

```text
Flutter 产品体验、页面结构、历史/收藏/缓存/下载/播放器交互：按 Kazumi 抄。
影视源、搜索、详情、播放地址解析、聚合逻辑：按 MoonTV 抄。
Flutter 工程基建：沿用 CineNest 现有 GetX + Dio + Hive + LoadingState，吸收 PiliPlus 写法。
Agent：保留为增强层，不参与基础播放闭环。
```

这里的“抄”指行为、结构、验收标准 1:1 对齐；实现代码要适配 CineNest 现有 Flutter 工程，不能直接把参考仓库业务耦合整坨搬进来。

---

## 1. 参考仓库调研结论

### 1.1 Kazumi：要抄的产品骨架

重点文件：

| 参考文件 | 要抄的东西 |
|---|---|
| `CodeReference/Kazumi/lib/pages/index_page.dart` | 首页框架、内容区组织、桌面/移动响应式 |
| `CodeReference/Kazumi/lib/pages/search/search_page.dart` | 搜索页结构、搜索历史、结果状态 |
| `CodeReference/Kazumi/lib/pages/info/info_page.dart` | 详情页信息层级、源选择入口、收藏入口 |
| `CodeReference/Kazumi/lib/pages/video/video_controller.dart` | 视频页状态机：集数、线路、播放会话、异步取消 |
| `CodeReference/Kazumi/lib/pages/player/player_controller.dart` | `media_kit` 播放控制、倍速、音量、进度、初始化失败处理 |
| `CodeReference/Kazumi/lib/pages/player/player_item.dart` | 播放器交互：手势、快捷键、全屏、控制面板 |
| `CodeReference/Kazumi/lib/services/video_source/video_source_service.dart` | 播放源解析接口、超时/取消/未找到异常 |
| `CodeReference/Kazumi/lib/services/video_source/webview_video_source_service.dart` | WebView 解析服务生命周期，注意只做降级，不做主链路 |
| `CodeReference/Kazumi/lib/repositories/history_repository.dart` | Hive 历史模型，按影片+源+集数记录进度 |
| `CodeReference/Kazumi/lib/repositories/collect_crud_repository.dart` | 本地收藏 CRUD 和同步变更记录 |
| `CodeReference/Kazumi/lib/pages/history/history_page.dart` | 历史页空态、编辑、清空、响应式网格 |
| `CodeReference/Kazumi/lib/pages/collect/collect_page.dart` | 收藏页结构和操作方式 |
| `CodeReference/Kazumi/lib/pages/download/download_page.dart` | 下载页信息层级 |
| `CodeReference/Kazumi/lib/services/download/download_manager.dart` | m3u8 下载、队列、并发、暂停恢复、空间检查 |
| `CodeReference/Kazumi/lib/utils/m3u8_parser.dart` | m3u8 playlist 解析 |
| `CodeReference/Kazumi/lib/services/network/proxy_aware_image_cache_manager.dart` | 图片缓存与代理感知 |

结论：

- Kazumi 的强项不是某一个 API，而是“播放器产品”的完整闭环。
- Step 1 不能只写 `SourceSearchService`，必须先搭出 Kazumi 式页面和播放状态机。
- 播放器错误不应该直接露出 Dio/Exception，必须被状态机吞掉并转成“换源/重试/查看详情”。

### 1.2 MoonTV：要抄的影视源内核

重点文件：

| 参考文件 | 要抄的东西 |
|---|---|
| `CodeReference/MoonTV/config.json` | 内置 MacCMS 源配置和自定义分类 |
| `CodeReference/MoonTV/src/lib/config.ts` | `ApiSite`、SourceConfig、启用/禁用、cache time |
| `CodeReference/MoonTV/src/lib/downstream.ts` | 搜索、详情、m3u8 提取、特殊源详情解析 |
| `CodeReference/MoonTV/src/app/api/search/route.ts` | 并发搜索启用源、过滤、缓存响应 |
| `CodeReference/MoonTV/src/app/api/detail/route.ts` | `source + id` 拉详情 |
| `CodeReference/MoonTV/src/app/play/page.tsx` | 播放页加载阶段、优选源、测速、换源、保存记录 |
| `CodeReference/MoonTV/src/components/EpisodeSelector.tsx` | 选集/换源双 Tab、分页、测速标签 |
| `CodeReference/MoonTV/src/components/VideoCard.tsx` | 搜索/收藏/历史共用影视卡片 |
| `CodeReference/MoonTV/src/components/ContinueWatching.tsx` | 继续观看横向列表 |
| `CodeReference/MoonTV/src/lib/db.client.ts` | localStorage 历史、收藏、搜索历史、跳过片头片尾配置 |
| `CodeReference/MoonTV/src/app/api/image-proxy/route.ts` | 图片代理缓存 |

MoonTV 的关键事实：

- 搜索阶段就会从 `vod_play_url` 提取 m3u8，结果天然带 `episodes`。
- 播放详情用 `?ac=videolist&ids=`，不是随便换成别的接口。
- 播放页有 `searching / preferring / fetching / ready` 阶段。
- 优选源不是用户点了才发现坏，而是先测速/探测，再选可用源。
- 历史和收藏主键是 `source + id`，不是 TMDB id。

结论：

- CineNest 的本地影视源内核应该优先移植 MoonTV，而不是从零写 MacCMS。
- 搜索结果必须包含“是否有可播 m3u8 / 集数数量 / 源名 / source key / id”。
- 首页展示的影视卡片必须来自“资料库 + 可播放源”合并结果，不能只展示 TMDB 热门。

### 1.3 PiliPlus：继续保留的 Flutter 基建

重点文件：

| 参考文件 | 要保留/借鉴的东西 |
|---|---|
| `CodeReference/PiliPlus/lib/http/init.dart` | Dio 初始化、错误映射、拦截器 |
| `CodeReference/PiliPlus/lib/http/loading_state.dart` | 页面 LoadingState 分层 |
| `CodeReference/PiliPlus/lib/utils/storage.dart` | Hive 初始化与 Box 管理 |
| `CodeReference/PiliPlus/lib/utils/cache_manager.dart` | 缓存管理 |
| `CodeReference/PiliPlus/lib/plugin/pl_player/` | 播放器控制组件和手势细节 |
| `CodeReference/PiliPlus/lib/services/download/download_manager.dart` | 下载服务组织方式 |

结论：

- CineNest 不需要再引入 B站账号、WBI、gRPC、弹幕业务。
- 但 GetX + Dio + Hive + LoadingState 继续作为 Flutter 工程骨架。
- UI 优先用官方 Material 3 组件和成熟 pub 包；少手写奇怪控件。

---

## 2. 新架构边界

### 2.1 Flutter 是完整影视播放器

Flutter 必须独立承担：

- 首页：继续观看、本地热播/可播放推荐、搜索入口、收藏入口、源管理入口。
- 搜索：MoonTV 式聚合搜索，首次搜索也必须有结果或明确空态。
- 详情：资料信息 + 播放源详情 + 集数 + 收藏 + 下载入口。
- 播放：Kazumi 式 `media_kit` 播放器，支持选集、换源、进度、错误恢复。
- 历史：本地 Hive 主存储，记录 `source + id + episode + position + duration`。
- 收藏：本地 Hive 主存储，记录 `source + id + title + cover + year + source_name`。
- 缓存：搜索缓存、详情缓存、图片缓存、源健康缓存。
- 下载：Step 3 开始做 mp4/m3u8 下载。

### 2.2 后端是增强层

FastAPI 继续负责：

- Agent 对话、智能推荐、资讯、海报。
- TMDB/豆瓣资料增强。
- B站、网盘、PC 本地资源、复杂反爬源。
- 图片代理、跨设备同步、源配置下发。

但后端不能阻塞这些基础功能：

- 普通搜索。
- 普通播放。
- 历史。
- 收藏。
- 首页基础展示。
- 封面占位和缓存。

---

## 3. 新目录方案

Step 1 起就按下面结构建，不再把搜索、解析、播放混在页面里：

```text
cine_nest_app/lib/
  models/media/
    media_identity.dart          # source + id / tmdb / douban 统一身份
    media_card.dart              # 搜索/历史/收藏/首页共用卡片数据
    media_detail.dart            # 详情资料
    media_episode.dart           # 集数与播放 URL
    play_session.dart            # 播放器入口参数
    source_config.dart           # MoonTV ApiSite 对齐模型
    source_health.dart           # 源健康、延迟、失败次数

  services/media_source/
    source_registry.dart         # assets seed + 本地覆盖 + 后端增量
    moontv_downstream.dart       # 1:1 移植 MoonTV downstream.ts 核心
    source_search_engine.dart    # 并发搜索 + 增量结果 + 缓存
    source_detail_engine.dart    # source + id 拉详情
    source_preflight_service.dart# m3u8 探测、源健康度、可播验证
    source_ranker.dart           # 精准标题、年份、集数、健康度排序

  repositories/media/
    search_cache_repository.dart
    detail_cache_repository.dart
    history_repository.dart
    favorite_repository.dart
    source_health_repository.dart
    skip_config_repository.dart

  pages/media_home/
    media_home_page.dart         # Kazumi/MoonTV 风格首页
    widgets/continue_watching_row.dart
    widgets/media_card.dart
    widgets/source_health_badge.dart

  pages/media_search/
    media_search_page.dart       # 搜索页
    media_search_controller.dart

  pages/media_detail/
    media_detail_page.dart
    media_detail_controller.dart
    widgets/episode_selector.dart
    widgets/source_selector.dart

  pages/player/
    player_page.dart
    player_controller.dart       # 仿 Kazumi PlayerController
    player_session_controller.dart
    widgets/player_surface.dart
    widgets/player_controls.dart
    widgets/source_switch_sheet.dart

  pages/history/
    history_page.dart
    history_controller.dart

  pages/favorite/
    favorite_page.dart
    favorite_controller.dart

  pages/source_manager/
    source_manager_page.dart
    source_manager_controller.dart
```

---

## 4. 四大 Steps 总览

| Step | 名称 | 抄谁 | 完成标志 |
|---|---|---|---|
| Step 1 | Kazumi/MoonTV 基础播放闭环 | Kazumi 首页/搜索/播放骨架 + MoonTV 搜索详情解析 | 后端关闭时：首页不空、搜索可用、结果已验证可播、播放 5 秒内进入画面或自动换源 |
| Step 2 | 源头稳定与资料库补齐 | MoonTV 源配置/图片代理 + TMDB 主资料/豆瓣辅助 | 封面不半灰，详情完整，搜索匹配准确，源健康可见可管理 |
| Step 3 | Kazumi 级播放器产品化与下载 | Kazumi/PiliPlus 播放器、历史、收藏、下载、设置 | 播放器手势/换源/选集/历史/收藏/下载形成完整产品体验 |
| Step 4 | Agent 无损耗回归 | CineNest 现有 Agent | Agent 推荐、资讯、海报、B站/网盘入口不坏，并能进入新详情/播放模型 |

---

## 5. Step 1：基础播放闭环重做

### 5.1 Step 1 目标

这一步只做一个目标：

```text
关闭 FastAPI 后端，Flutter 仍然像一个正常影视播放器一样可用。
```

必须做到：

- Home 不空。
- 搜索第一次就能搜。
- 搜索结果只把“至少有一条 m3u8/mp4 直链”的源放到主要列表。
- 点播放后 5 秒内进入画面；失败自动试下一个健康源。
- 用户界面不直接展示 DioException、StackTrace、Bad state。
- 历史、收藏本地可用。
- WebView 不算 Step 1 主播放成功，只能作为“手动降级入口”。

### 5.2 Step 1 任务包

#### 1.1 撤掉现有后端壳首页，重建 MediaHome

参考：

- `Kazumi/lib/pages/index_page.dart`
- `MoonTV/src/components/ContinueWatching.tsx`
- `MoonTV/src/components/VideoCard.tsx`

要做：

- 新建 `pages/media_home/`。
- 首页首屏结构：
  - 搜索栏。
  - 继续观看横向列表。
  - 本地可播放热门片单。
  - 我的收藏快捷入口。
  - 源管理入口。
- 后端关闭时仍展示本地缓存/内置可播放片单。
- 首页卡片统一用 `MediaCard`，不要每页重复写封面卡。

验收：

- 关闭 FastAPI，Home 不是空白。
- 首页卡片封面失败时显示干净占位，不半灰、不随机图。
- 首页任一卡片点击后能进入详情或直接播放。

#### 1.2 移植 MoonTV SourceConfig 和 Downstream

参考：

- `MoonTV/src/lib/config.ts`
- `MoonTV/src/lib/downstream.ts`
- `MoonTV/config.json`

要做：

- 新建 `source_config.dart`，字段对齐 MoonTV `ApiSite`：
  - `key`
  - `name`
  - `api`
  - `detail`
  - `disabled`
  - `from`
  - `order`
- 新建 `assets/sources/moontv_sources.json`，从 MoonTV `config.json` 迁移源。
- 新建 `moontv_downstream.dart`，移植：
  - `searchFromApi`
  - `getDetailFromApi`
  - m3u8 正则提取
  - `vod_play_url` 的 `$$$` 分组处理
  - 特殊源 detail 处理接口预留
- MacCMS 详情接口使用 MoonTV 的 `?ac=videolist&ids=`。

验收：

- 单源搜索返回 `MediaCard`。
- 单源详情返回 `MediaDetail + episodes`。
- `episodes` 只包含 http/https 且可被识别为 m3u8/mp4 的 URL。

#### 1.3 搜索引擎必须“增量返回 + 可播验证”

参考：

- MoonTV `/api/search/route.ts`
- MoonTV `downstream.ts`
- Kazumi 搜索页状态设计

要做：

- `SourceSearchEngine.search(keyword)` 不等待所有源结束才显示。
- 快源先返回，慢源后台补。
- 每源 timeout 默认 4 秒，详情/测速 timeout 默认 5 秒。
- 搜索阶段提取 m3u8；没有直链的结果降级为“网页源”，不进入主结果顶部。
- 结果排序：
  1. 标题精确匹配。
  2. 年份匹配。
  3. 有 m3u8/mp4 直链。
  4. 集数数量合理。
  5. 源健康度高。
- 错误进入 debug 面板，不在普通 UI 红框展示。

验收：

- 第一次搜索 `肖申克的救赎`、`庆余年`、`甄嬛传`，不允许出现“第一次啥都搜不到，第二次才有”的情况。
- 搜索 2 秒内应至少出现缓存/快源结果或明确加载进度。
- UI 不展示 DioException 原文。

#### 1.4 播放入口按 Kazumi 状态机重建

参考：

- `Kazumi/lib/pages/video/video_controller.dart`
- `Kazumi/lib/services/video_source/video_source_service.dart`
- `MoonTV/src/app/play/page.tsx`

要做：

- 新建 `PlaySession`，包含：
  - `mediaId`
  - `title`
  - `cover`
  - `source`
  - `sourceName`
  - `remoteId`
  - `episodes`
  - `currentEpisode`
  - `headers`
  - `resumePosition`
- 新建 `PlayerSessionController`：
  - `searching`
  - `preferring`
  - `opening`
  - `playing`
  - `switching`
  - `failed`
- 支持异步取消 token，用户换片/换集时旧请求必须失效。
- 播放失败 5 秒内自动试下一个源。
- 只有所有源失败才显示用户可读错误。

验收：

- 点播放不是 20 秒黑屏转圈。
- 单源坏时自动换源。
- 所有源坏时提示“未找到可播放直链，去源管理检查”，不显示 `Bad state`。

#### 1.5 播放器页面按 Kazumi/PiliPlus 先做基础版

参考：

- `Kazumi/lib/pages/player/player_controller.dart`
- `Kazumi/lib/pages/player/player_item.dart`
- `PiliPlus/lib/plugin/pl_player/`

Step 1 只做基础版：

- `media_kit` 播放 m3u8/mp4。
- 播放/暂停。
- 进度条。
- 倍速。
- 全屏。
- 选集。
- 换源。
- 重试。
- 自动保存进度。

暂不做：

- 弹幕。
- 投屏。
- 超分。
- 同步播放。
- 截图。
- 下载。

验收：

- 播放成功后 10 秒保存历史。
- 退出再进能恢复进度。
- 横竖屏/窗口大小变化不遮挡控制栏。

#### 1.6 本地历史和收藏按 Kazumi/MoonTV 模型重建

参考：

- `Kazumi/repositories/history_repository.dart`
- `Kazumi/repositories/collect_crud_repository.dart`
- `MoonTV/lib/db.client.ts`

要做：

- Hive Box：
  - `mediaHistory`
  - `mediaFavorites`
  - `searchHistory`
  - `sourceHealth`
  - `skipConfigs`
- 历史主键：`source + id`。
- 历史记录：
  - 标题、封面、年份、source、sourceName、当前集、总集数、playTime、duration、saveTime、searchTitle。
- 收藏记录：
  - 标题、封面、年份、source、sourceName、总集数、saveTime。

验收：

- 后端关闭时历史页可看、可删、可清空。
- 后端关闭时收藏页可看、可删。
- 播放记录能从历史继续播放。

#### 1.7 Step 1 接口归宿清单

| 后端接口 | Step 1 后归宿 |
|---|---|
| `/api/sources/search` | 不再是 Flutter 普通搜索主路径；只保留调试/PC 增强 |
| `/api/sources/parse` | 保留为高级兜底，不参与 Step 1 主验收 |
| `/api/play/resolve` | Agent/Creative 增强兜底 |
| `/api/discovery` | 资料增强；Home 不可依赖它才显示 |
| `/api/movie/{id}` | TMDB/豆瓣详情增强；播放详情不依赖它才可播 |
| `/api/history` | 多设备同步接口；本地 Hive 为主 |
| `/api/collections/toggle` | 多设备同步接口；本地 Hive 为主 |
| `/api/proxy/image` | 图片代理兜底；TMDB/CDN/缓存优先 |

### 5.3 Step 1 最终验收

验收必须关掉 FastAPI。

1. 启动 Flutter。
2. Home 首屏有内容，不空白。
3. 搜索 `肖申克的救赎`，第一次搜索必须有结果或明确空态。
4. 搜索 `庆余年`，结果里至少出现一个可播源。
5. 点播放，5 秒内进入画面；如果单源失败，看到“正在切换源”，不是红色异常。
6. 播放 10 秒退出。
7. 历史页出现记录。
8. 从历史页继续播放。
9. 收藏/取消收藏可用。
10. UI 全程不出现 DioException、Bad state、StackTrace。

---

## 6. Step 2：源头稳定与资料库补齐

### 6.1 目标

Step 2 不做花哨功能，只解决“更多、更稳、更准、更好看”。

### 6.2 任务包

#### 2.1 源管理器产品化

参考：

- MoonTV 管理员 source config。
- Kazumi plugin 管理。

要做：

- 源列表页：
  - 启用/禁用。
  - 拖拽排序。
  - 健康状态。
  - 最近成功时间。
  - 平均延迟。
  - 失败次数。
- 支持导入 MoonTV `api_site` 格式。
- 支持从后端拉增量源，但本地 assets seed 必须可独立启动。

验收：

- 可禁用坏源。
- 坏源不会拖慢主搜索。
- 源健康度影响排序。

#### 2.2 TMDB 主资料，豆瓣辅助

要做：

- TMDB 作为主资料库：
  - 标题、原名、年份、海报、背景、简介、类型、演员、导演、相似推荐。
- 豆瓣作为中文辅助：
  - 中文热度、评分感知、条目补充。
- 资源站作为可播放事实来源。

匹配顺序：

```text
source title/year/douban_id
  -> TMDB search/detail
  -> Douban 辅助匹配
  -> source fallback
```

验收：

- 详情页不因 TMDB 失败而白屏。
- TMDB 图优先，不再半灰一片。
- 资源站封面差时能用 TMDB 海报替换。

#### 2.3 图片系统重做

要做：

- 统一 `ImageResolver`。
- TMDB 图片：
  - 列表 `w342/w500`。
  - 背景 `w780`。
  - 不在列表拉 original。
- 豆瓣图：
  - 必要时走后端 proxy。
- 资源站图：
  - 支持 referer/header 配置。
- 缓存：
  - 海报 30 天。
  - 背景 14 天。
  - 失败负缓存 10 分钟。
- UI：
  - skeleton 或带片名占位。
  - 不显示半张灰图。

验收：

- 首页滚动时封面不大片灰。
- 搜索结果封面加载失败不影响点击和布局。
- 重启 App 后已看过图片从缓存出。

#### 2.4 搜索质量提升

要做：

- 标题归一化：空格、标点、繁简、季/部/第几季。
- 年份权重。
- 电影/剧集类型判断。
- 同名聚合。
- 黄暴过滤保留 MoonTV 思路。
- 搜索历史。
- 热门关键词。

验收：

- `肖申克的救赎` 不应主要返回解说。
- `庆余年` 能聚合多源。
- `甄嬛传` 能返回剧集源。

---

## 7. Step 3：Kazumi 级播放器产品化与下载

### 7.1 播放器产品化

参考：

- Kazumi `player_controller.dart` / `player_item.dart`
- PiliPlus `pl_player`

任务：

- 手势：
  - 左右滑进度。
  - 左侧亮度。
  - 右侧音量。
  - 双击播放暂停。
  - 长按倍速。
- 控制：
  - 倍速。
  - 画面比例。
  - 快进快退秒数设置。
  - 自动下一集。
  - 后台播放设置。
  - 外部播放器。
- 面板：
  - 选集。
  - 换源。
  - 播放设置。
  - 跳片头片尾。
  - 错误诊断入口。

验收：

- 播放器不再像 demo。
- 选集/换源不用退出播放器。
- 错误恢复路径清楚。

### 7.2 历史、收藏、搜索历史产品化

任务：

- 历史页：
  - 继续播放。
  - 编辑/删除/清空。
  - 按时间分组。
  - 进度条。
- 收藏页：
  - 网格。
  - 搜索收藏。
  - 删除。
  - 继续播放。
- 搜索历史：
  - 最近 20 条。
  - 一键清空。

验收：

- 这些功能后端关闭仍可用。

### 7.3 下载管理分三段做

参考：

- Kazumi `download_manager.dart`
- Kazumi `m3u8_parser.dart`
- PiliPlus download service

#### 3.7a mp4 单文件下载

- 队列。
- 暂停/继续。
- 删除。
- 下载目录设置。

验收：

- mp4 可下载、可暂停恢复、可本地播放。

#### 3.7b m3u8 下载

- master/media playlist 解析。
- ts/m4s 分片。
- key 下载和 AES 解密。
- 分片并发。
- 本地 playlist 生成。

验收：

- m3u8 剧集可离线观看。

#### 3.7c 后台下载

- 后台任务。
- 通知。
- 断点续传。
- 空间检查。

验收：

- App 切后台下载不中断或能恢复。

---

## 8. Step 4：Agent 无损耗回归

Step 4 原则上不是大开发，而是回归验收和少量适配。

### 8.1 要保证不坏的功能

- Chat Agent 对话。
- 智能推荐。
- MicroDesign 海报。
- 资讯。
- B站/网盘/PC 资源增强入口。
- 后端同步历史/收藏。

### 8.2 Agent 接入新媒体模型

Agent 输出不再直接塞旧播放接口，而是统一输出：

```json
{
  "title": "影片名",
  "year": "年份",
  "tmdb_id": "可选",
  "douban_id": "可选",
  "intent": "play|detail|recommend",
  "preferred_source": "可选"
}
```

Flutter 接到后：

```text
Agent card
  -> MediaDetailPage
  -> SourceSearchEngine / DetailCache
  -> PlayerPage
```

后端只作为增强来源，不替代本地播放闭环。

### 8.3 验收

- Agent 推荐卡片能进入新详情页。
- 推荐影片能走本地源搜索播放。
- 本地源失败时再请求后端增强解析。
- 资讯、海报、聊天不因播放器重构损坏。

---

## 9. 绝对禁止事项

后续 AI/开发者必须遵守：

- 禁止把后端 `/api/sources/search` 重新作为 Flutter 普通搜索主路径。
- 禁止把 WebView 当成 Step 1 主播放成功。
- 禁止把 DioException/Bad state/StackTrace 直接展示给用户。
- 禁止搜索等待所有源结束才展示结果。
- 禁止首页依赖后端才有内容。
- 禁止只写模型/服务不接真实页面验收。
- 禁止未验证可播就宣称播放解耦完成。
- 禁止修改 `CodeReference/`。

---

## 10. 给下一轮实现 AI 的最小执行顺序

不要自由发挥，按这个顺序做：

1. 只读调研：
   - Kazumi `index/search/video/player/history/collect/download`。
   - MoonTV `config/downstream/play/EpisodeSelector/VideoCard/db.client`。
2. 建 `models/media`。
3. 建 `services/media_source/moontv_downstream.dart`，先单元测试解析 MoonTV 格式。
4. 建 `source_search_engine.dart`，实现增量搜索和可播过滤。
5. 建 `media_home_page.dart`，后端关闭也有内容。
6. 建 `media_search_page.dart`，第一次搜索必须可用。
7. 建 `media_detail_page.dart`，展示源和集数。
8. 建 `player_page.dart` 和播放状态机。
9. 接本地 history/favorite。
10. 关后端完整验收。

每一步完成必须更新：

- `docs/modules/player.md`
- `docs/api_contract.md`
- 对应模块验收记录

---

## 11. Step 1 评分标准

按 Kazumi 10 分为标尺，Step 1 至少要达到 6 分才算过：

| 项 | 0 分表现 | 过线表现 |
|---|---|---|
| Home | 空白/后端依赖 | 后端关掉仍有可播放内容 |
| 搜索 | 首次无结果/红框异常 | 首次可用，快源增量返回 |
| 源质量 | 点进去才知道坏 | 主列表优先可播直链 |
| 播放 | 20 秒转圈/WebView | 5 秒内播放或自动换源 |
| 错误态 | Bad state/DioException | 用户可读提示 + 调试入口 |
| 历史 | 请求后端 | 本地 Hive 主存储 |
| 收藏 | 请求后端 | 本地 Hive 主存储 |
| 封面 | 半灰/随机图 | 缓存 + 占位 + TMDB 优先 |

没有达到这张表，不允许再说 Step 1 完成。
