# 场景化推荐（新独立页面）实现计划

该计划将“场景化推荐”从首页分离出来，作为一个独立的功能模块，支持手动输入场景描述，并确保其推荐逻辑具有最高优先级。

## 用户评审需求

- **交互入口**：计划在 `DiscoveryPage`（探索页）新增一个“心情/场景找片”的大横幅入口。
- **流程可视化**：后端将增加 `trace` 信息，在接口返回中说明 LLM 是如何解析关键词的，以便调试和查看。
- **推荐优先级**：当用户指定 `scenario` 时，后端将**忽略**常规的 `liked_genres`（仅作为背景参考），完全围绕场景词进行搜索。

## 方案设计

### 1. 后端逻辑优化 (cine_net_backend)

- **接口增强**：
    - `/api/feed` 返回增加可选的 `debug_info` 字段，包含关键词转换过程。
- **Agent 服务优化 (`MovieAgentService`)**：
    - 调整 prompt，明确告诉 LLM：用户当前的“心情/场景”是**绝对核心**，用户偏好（如“喜欢动作片”）仅在多个候选不相上下时用于二次排序，不能喧宾夺主。
    - 在返回结果中包含 `smart_query` 的原始解析结果。

### 2. 前端页面实现 (cine_nest_app)

- **新页面 `ScenarioPage`**：
    - 顶部一个醒目的搜索框/输入框，支持手动输入（如“想看点甜的”）。
    - 下方保留快捷场景 Chip。
    - 列表展示推荐结果，并显示“AI 理由”。
- **路由注册**：在 `app_pages.dart` 注册 `/scenario` 路由。
- **入口调整**：从 `DiscoveryPage` 的顶部横幅进入，或者从 `FeedPage` 移除之前的 Chip 栏，改为一个“试试按心情找片”的入口按钮。

---

## 拟修改文件

### 后端 (cine_net_backend)

#### [services/agent/service.py](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_net_backend/services/agent/service.py)

- 优化 `_smart_search_query`：返回关键词的同时，记录解析过程。
- 优化 `_agent_reason_map`：强化“场景优先”的 prompt。

#### [models/schemas.py](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_net_backend/models/schemas.py)

- 在 `Post` 或新增的 `ScenarioResponse` 中增加 `debug_trace`。

### 前端 (cine_nest_app)

#### [NEW] [scenario_view.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/pages/feed/scenario/scenario_view.dart)
#### [NEW] [scenario_controller.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/pages/feed/scenario/scenario_controller.dart)

#### [lib/pages/feed/feed_view.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/pages/feed/feed_view.dart)

- 移除 Chip 栏，改为一个跳转到 `ScenarioPage` 的入口。

#### [lib/router/app_routes.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/router/app_routes.dart) & [lib/router/app_pages.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/router/app_pages.dart)

- 注册新路由。

---

## 验证计划

### 自动化测试
- **后端**：更新 `tests/test_scenario_feed.py`，测试手动输入场景时的优先级逻辑。

### 手动验证
- 启动 App，点击探索页的“心情找片”。
- 输入“我想看科幻大片”，验证返回的是否主要是科幻片（即使我的偏好设置是“爱情片”）。
- 查看控制台日志（或 UI 上的调试信息），确认 LLM 转换的关键词准确。
