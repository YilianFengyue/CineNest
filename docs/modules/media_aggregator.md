# 模块开发说明 - Media Aggregator（本地聚合器）

## 1. 模块目标

新建 Flutter 本地聚合器，按 MoonTV 的资源站内核思路实现：

- 从 `assets/sources/moontv_sources.json` 读取 MacCMS `api_site` 源。
- 手机端本地并发搜索，不依赖 FastAPI 基础闭环。
- 搜索阶段解析 `vod_play_url`，优先返回 m3u8/mp4 直链结果。
- 详情阶段使用 `source + remoteId` 拉取 `?ac=videolist&ids=`。
- 源健康、缓存、排序、错误 trace 都在 Flutter 侧完成。
- 后端 Catalog/TMDB 只作为可选海报和资料增强，失败不影响播放。

该模块不删除、不替换现有后端视频源链路，先通过 Temple 页面验证，后续再接 Kazumi 风首页、搜索页和详情页。

## 2. 涉及文件

| 文件 | 作用 |
|---|---|
| `cine_nest_app/assets/sources/moontv_sources.json` | MoonTV 风内置 MacCMS 源种子 |
| `cine_nest_app/lib/modules/media_aggregator/models/` | 聚合器 Source、SearchResult、Detail、Episode、PlaySession、Health 模型 |
| `cine_nest_app/lib/modules/media_aggregator/services/moontv_downstream.dart` | MoonTV 下游协议移植：搜索、详情、HTML 特殊源、m3u8/mp4 提取 |
| `cine_nest_app/lib/modules/media_aggregator/services/aggregator_search_engine.dart` | 并发增量搜索、缓存、健康记录、排序、可选资料增强 |
| `cine_nest_app/lib/modules/media_aggregator/services/aggregator_detail_engine.dart` | 详情加载、播放会话构建、播放前探测 |
| `cine_nest_app/lib/modules/media_aggregator/repositories/` | Hive dynamic box 存源配置、搜索缓存、详情缓存、源健康 |
| `cine_nest_app/lib/modules/media_aggregator/pages/aggregator_temple_page.dart` | 聚合器测试入口 |
| `cine_nest_app/lib/modules/media_aggregator/pages/aggregator_detail_temple_page.dart` | 详情和集数测试页 |
| `cine_nest_app/lib/modules/media_aggregator/pages/aggregator_player_host_page.dart` | 聚合器播放会话接 Kazumi 播放器 |
| `cine_nest_app/lib/modules/media_aggregator/pages/source_manager_temple_page.dart` | 源启用/禁用和健康记录测试页 |

## 3. 核心接口形状

搜索入口：

```dart
Stream<AggregatorSearchBatch> search(String keyword)
```

每个 batch 包含：

- `results`：当前已聚合结果。
- `traces`：每个源的成功/失败、耗时、结果数。
- `completedSources / totalSources`：进度。
- `fromCache`：是否先返回缓存。

详情入口：

```dart
Future<AggregatorMediaDetail> loadDetail(AggregatorSearchResult result)
```

播放入口：

```dart
Future<AggregatorPlaySession> buildPlaySession(
  AggregatorMediaDetail detail, {
  int episodeIndex = 0,
})
```

`AggregatorPlaySession.playUrl` 最终交给 `KazumiPlayerController.open()`。

## 4. 高可用策略

- 单源失败只写 trace 和健康记录，不中断整体搜索。
- 搜索默认并发池为 6，快源先返回。
- 搜索缓存默认 2 小时，详情缓存默认 6 小时。
- 源健康记录平均延迟、成功数、失败数，并影响排序。
- 播放前先探测当前集；失败时尝试同详情内其它可播集地址。
- TMDB/Catalog 增强失败直接降级，不阻塞搜索、详情、播放。

## 5. Temple 验收步骤

1. 关闭 FastAPI 后端。
2. 启动 Flutter。
3. 进入 `Settings -> 聚合器 Temple`。
4. 搜索 `肖申克的救赎`，确认有结果或清楚的源 trace。
5. 搜索 `庆余年`，确认剧集源能返回集数。
6. 点结果进入详情页，确认集数网格显示。
7. 点某一集试播，进入 Kazumi 风播放器。
8. 返回源管理页，禁用一个源后重新搜索，确认该源不再参与。
9. UI 不应显示 DioException、Bad state、StackTrace 原文。

## 6. 当前测试结果

- `flutter analyze`：新模块无 error；当前工程仍有一个既有旧文件 unused import warning，位置 `lib/pages/feed/widgets/post_card.dart:3`。
- 后端关闭验收：待真机/模拟器人工走查。
