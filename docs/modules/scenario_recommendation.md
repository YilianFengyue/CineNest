# 场景化推荐入口 (Scenario-based Recommendation)

该模块允许用户通过“心情”或“场景”而非具体的电影名称来获取推荐。

## 实现功能点

- **F5-S1**：首页新增横向场景选择 Chip 栏。
- **F5-S2**：后端 Agent 语义解析，将场景（如“下饭电影”）转换为 TMDB 搜索关键词。
- **F5-S3**：生成的推荐理由自动适配场景语境。

## 关键接口用法

### GET `/api/feed`
- **参数**：`scenario` (string, 可选) - 场景描述，如 `今晚想放松`。
- **返回**：`Post[]` - 针对该场景筛选的电影列表。

## 验收清单测试结果

| 功能点 | 测试描述 | 结果 |
|---|---|---|
| 场景切换 | 点击“下饭电影”，UI 显示 Loading 并刷新列表 | 通过 (Manual) |
| 语义搜索 | 传入 `scenario=想看爽片`，后端成功调用 LLM 转换为关键词并搜索 | 通过 (Unit Test) |
| 理由适配 | 推荐理由中包含场景相关的描述 | 通过 (Unit Test) |

## 自动化测试结果
运行 `pytest tests/test_scenario_feed.py`，结果如下：
```
tests\test_scenario_feed.py .. [100%]
2 passed in 1.23s
```
