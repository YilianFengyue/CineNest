# AGENTS.md — CineNest 开发协作铁律

> 本文件供团队成员与 AI 编码助手共同遵守。开工前必读。

## 项目一句话
PC 端（`cine_net_backend`，FastAPI + LangChain）做算力中心，手机端（`cine_nest_app`，
Flutter）做交互界面，AI 为用户策展个性化影视推荐。完整需求见
[docs/CineAgent-需求与计划书.md](docs/CineAgent-需求与计划书.md)。

## 架构母版
手机端基建**仿照 `CodeReference/PiliPlus`**（GetX + Dio + Hive + LoadingState 分层），
已剔除其全部 B站强相关逻辑（WBI 签名 / AccountManager / cookie / 弹幕 / gRPC）。
`CodeReference/` 为只读参考，**禁止修改**。

## 三条铁律

### 1. 按功能点人工验收
- 所有功能对照《需求与计划书》F1–F12 的**验收标准**逐条人工走查。
- 一个功能点「完成」的定义 = 演示给另外两人看 + 验收清单全部打勾，不是「代码写完」。

### 2. 每个模块完成必须写说明文档 + 测试结果
- 位置：`docs/modules/<模块名>.md`（模板 `docs/modules/_TEMPLATE.md`）。
- 内容：实现了哪些功能点 + 关键接口用法 + **验收清单逐条测试结果（附截图/接口返回）**。
- 目的：他人无需通读代码即可接手、联调、协作。**没有文档的模块视为未完成。**

### 3. 不交叉修改别人的模块
- 共建区（`http/ utils/ services/ common/ models/ router/` 与后端 `config.py models/`）
  改动前先同步；各自业务模块目录内自治。
- 模块间只通过 **API 契约 + 路由跳转** 连接，见 [docs/api_contract.md](docs/api_contract.md)。

## 分工速查
| 成员 | 功能 | 前端目录 | 后端 |
|------|------|---------|------|
| A | F3 播放器 / F4 视频源 / F7 连接 | `pages/player/` | `routers/sources.py`、`services/video_engine/` |
| B | F1 帖子流 / F2 详情 / F5 Agent / F6 偏好 | `pages/feed/` | `routers/feed.py`、`services/{agent,tmdb}/`、`db/` |
| C | F8 海报 / F9 对话 / F12 资讯 | `pages/creative/` | `routers/{chat,poster}.py`、`services/{poster,news}/` |

## 提交前自检
- Flutter：`cd cine_nest_app && flutter analyze` 无 error
- 后端：`cd cine_net_backend && python -m py_compile $(目标文件)` 无报错
- 不提交 `.env`、`*.db`、`build/`、`.dart_tool/`
- commit message 格式：`[模块] 动词 + 内容`

## 给 AI 助手的额外约定
- 改动需求文档/契约时，**同步**改 Flutter `lib/models/` 与后端 `models/schemas.py`。
- 新增 Flutter 依赖前确认与 Flutter 3.35 / Dart 3.9 兼容，改完跑 `flutter pub get`。
- 写中文注释，Python 接口标 `TODO(谁)`。
