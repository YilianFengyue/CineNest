# CineNest — AI 驱动的个性化影视推荐 App

PC 端（FastAPI + LangChain）做算力中心，手机端（Flutter）做交互界面，AI 为用户策展私人影院入口。

## 仓库结构
- `cine_nest_app/` — 手机端 Flutter（Android / HarmonyOS），架构母版 PiliPlus
- `cine_net_backend/` — PC 端 FastAPI + LangChain
- `docs/` — 文档（先读 [项目说明-快速上手](docs/项目说明-快速上手.md)）
- `AGENTS.md` — 开发协作铁律（**开工前必读**）
- `CodeReference/PiliPlus/` — 架构参考母版（GPL-3.0，**本地参考、不入库**）

> 参考母版未上传到本仓库（GPL 许可 + 体积大 + 含嵌套 .git）。需要参考时本地克隆到
> `CodeReference/` 下即可：`git clone https://github.com/bggRGjQaUbCoE/PiliPlus CodeReference/PiliPlus`

## 快速开始
见 [docs/项目说明-快速上手.md](docs/项目说明-快速上手.md)。

```bash
# 后端
cd cine_net_backend && pip install -r requirements.txt && uvicorn main:app --reload
# 手机端
cd cine_nest_app && flutter pub get && flutter run
```

## 可选能力：AutoGLM 手机控制
后端已接入 AutoGLM 手机子 Agent，用于让主 Agent 派发“打开 App、搜索、浏览”等手机自动化任务。
该能力默认关闭；没安装 AutoGLM 或没配置 `PHONE_*` 时，不影响普通后端接口、推荐、播放资源和聊天基础能力。

需要启用时，按 [快速上手文档](docs/项目说明-快速上手.md#autoglm-手机控制可选) 安装
`CodeReference/Open-AutoGLM` 并补充 `cine_net_backend/.env`。
