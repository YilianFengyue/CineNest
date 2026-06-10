# 电影关系图谱功能实现计划

该功能将在电影详情页底部展示一个交互式图谱，连接导演、主演、同类型电影、相似题材及推荐电影。

## 用户评审需求

- **图谱位置**：电影详情页“剧情简介”和“演职员”下方。
- **图谱内容**：
    - 中心节点：当前电影。
    - 关联节点：导演、主演（前3）、类型标签、关键词/题材（如“梦境”、“烧脑”）、相似/推荐电影（前4）。
- **交互**：点击电影节点跳转到对应详情页；点击人物/类型节点执行搜索（可选）。

## 方案设计

### 1. 后端接口 (cine_net_backend)

- **新增接口**：`GET /api/movie/{movie_id}/graph`
- **数据来源**：
    - `TMDB /movie/{id}/keywords`：获取题材标签。
    - `TMDB /movie/{id}/credits`：获取导演和主演。
    - `TMDB /movie/{id}/recommendations`：获取关联电影。
- **返回结构**：
    ```json
    {
      "nodes": [
        {"id": "m1", "label": "盗梦空间", "type": "movie", "movie_id": 27205},
        {"id": "p1", "label": "诺兰", "type": "person"},
        {"id": "g1", "label": "科幻", "type": "genre"}
      ],
      "links": [
        {"source": "m1", "target": "p1", "relation": "导演"},
        {"source": "m1", "target": "g1", "relation": "类型"}
      ]
    }
    ```

### 2. 前端实现 (cine_nest_app)

- **数据模型**：新增 `GraphNode` 和 `GraphLink` 模型。
- **图谱组件 (`MovieGraphWidget`)**：
    - 使用 `CustomPainter` 或 `Stack + Positioned` 实现一个简单的星型布局图谱。
    - 中心是当前电影，周围环绕关联节点。
- **控制器增强**：`MovieDetailController` 增加 `fetchMovieGraph()`。

---

## 拟修改文件

### 后端 (cine_net_backend)

#### [services/tmdb/service.py](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_net_backend/services/tmdb/service.py)
- 增加 `get_movie_graph(movie_id)` 方法，聚合多方数据。

#### [routers/feed.py](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_net_backend/routers/feed.py)
- 暴露 `/api/movie/{movie_id}/graph` 路由。

### 前端 (cine_nest_app)

#### [lib/models/movie_graph.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/models/movie_graph.dart)
- [NEW] 定义图谱数据结构。

#### [lib/pages/feed/detail/detail_controller.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/pages/feed/detail/detail_controller.dart)
- 增加图谱数据抓取逻辑。

#### [lib/pages/feed/detail/widgets/movie_graph_widget.dart](file:///D:/code/undergraduated_3_down/Android/CineNest/cine_nest_app/lib/pages/feed/detail/widgets/movie_graph_widget.dart)
- [NEW] 图谱 UI 组件。

---

## 验证计划

### 自动化测试
- **后端**：编写测试脚本验证 `/api/movie/{id}/graph` 返回的节点数和链接逻辑是否正确。

### 手动验证
- 进入《盗梦空间》详情页，滑动到底部。
- 确认图谱显示了“诺兰”、“莱昂纳多”等节点。
- 点击图谱中的“星际穿越”节点，验证是否成功跳转。
