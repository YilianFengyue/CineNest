# 模块开发说明 · 分支合并与 Agent/Feed 衔接（成员 A/B/C）

## 1. 本次合并目标
- 保留成员 C 的主 Agent、F8 海报、F9 对话、F12 资讯与 MicroDesign 推荐能力。
- 恢复成员 B 的首页 Feed、探索页、偏好、观影历史、收藏、TMDB 图片代理。
- 恢复成员 A 的视频源搜索、解析、播放器、WebView 降级与连接设置入口。
- 消除第二套 DeepSeek Agent：B 的旧 `movie_agent_service` 入口保留，但内部并入 C 主 Agent 体系。

## 2. 关键变动
| 文件 | 变动 |
|------|------|
| `cine_net_backend/services/agent/service.py` | 新的 B Feed 兼容层，继续导出 `movie_agent_service`。不再直接维护 DeepSeek `client/engine/tools`。 |
| `cine_net_backend/routers/feed.py` | `/api/feed` 归 B 首页使用；`/api/feed/recommend` 归 C 确定性 MicroDesign 推荐；旧关键词 MicroDesign Feed 挪到 `/api/feed/microdesign`。 |
| `cine_net_backend/db/database.py` | 统一使用 SQLite，补齐 B 的偏好、历史、收藏函数；不再使用 JSON 状态文件作为主存储。 |
| `cine_net_backend/main.py` | 保留 C 全量 router，同时加回 B 的请求日志、`/api/ping_debug`、`/api/proxy/image`。 |
| `cine_nest_app/lib/pages/main/main_app.dart` | Home 接 B 的 `DiscoveryPage`，Chat 保持 C 全屏体验，News 接 C 资讯，Settings 接 B 偏好与 A 连接设置。 |
| `cine_nest_app/lib/router/app_pages.dart` | A/B/C 路由统一注册。 |
| `cine_nest_app/lib/http/api_constants.dart` | A/B/C API 常量统一整理，默认 baseUrl 回到 `127.0.0.1:8000`。 |

## 3. 给成员 B 的衔接方式
B 前端不用改已有主调用：

```dart
Request().get(ApiConstants.feed)
```

仍然对应：

```text
GET /api/feed
```

后端仍然通过：

```python
from services.agent.service import movie_agent_service
```

但现在 `movie_agent_service` 是 C 主 Agent 包里的兼容服务：
- 有 TMDB Key 时：先用偏好/关键词取候选电影。
- C 主 Agent 配置可用时：尝试生成一句话推荐理由。
- 主 Agent 或 TMDB 不可用时：`routers/feed.py` 会回退到本地 `FALLBACK_MOVIES`，保证首页不白屏。

B 后续如果要继续增强推荐，不要恢复旧 DeepSeek `client/engine/tools`；建议只扩展：

```text
cine_net_backend/services/agent/service.py
cine_net_backend/routers/feed.py
```

## 4. 给成员 A 的衔接方式
A 播放器入口保持：

```text
GET /api/sources/search?movie_name=...
GET /api/sources/parse?source_id=...
GET /api/bilibili/search?keyword=...
```

对应前端：

```text
Routes.sourcePicker
Routes.player
Routes.webviewPlayer
```

成员 C 的 `/api/play/resolve` 也保留，主要给 Agent/Creative 卡片跳转播放器时用。

## 5. 测试结果
| 验收项 | 结果 | 证据 |
|--------|------|------|
| Git 冲突标记清除 | 通过 | `rg "^(<<<<<<<|=======|>>>>>>>)"` 无输出 |
| 后端编译 | 通过 | `python -m py_compile main.py db\database.py routers\feed.py routers\sources.py services\agent\service.py ...` |
| 后端启动链路导入 | 通过 | `from main import app`，关键路由共 48 条 |
| 后端接口 smoke | 通过 | `/api/ping_debug`、`/api/preferences`、`/api/history`、`/api/discovery`、`/api/feed` 均返回 200 |
| Flutter 依赖 | 通过 | `flutter pub get` 成功重建 `pubspec.lock` |
| Flutter 静态检查 | 通过 | `flutter analyze`：No issues found |

## 6. 已知注意点
- 当前本地 `.env` 的 TMDB Key 无效时，后端会打印 401，但 `/api/discovery` 和 `/api/feed` 会 fallback 返回本地电影，不影响基础演示。
- `cine_net_backend/db/cinenest_state.json` 是远端 B 带来的旧 JSON 状态文件；合并后主存储已切 SQLite，后续可清理或加入忽略，但本次未擅自删除远端文件。
