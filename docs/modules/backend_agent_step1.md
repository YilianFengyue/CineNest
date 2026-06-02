# 后端 Agent Step 1 验收教程

> 当前范围：FastAPI + LangChain Agent Core、20 个 MacCMS Provider、多源检索、详情解析、MicroDesign 帖子与动态海报 blocks。

## 1. 已完成能力

- OpenAI Chat Completions 兼容模型工厂：仅需填写 `LLM_API_KEY / LLM_BASE_URL / LLM_MODEL`。
- LangChain v1 `create_agent()` 底座：统一 Tool Registry、`thread_id` 多轮会话、REST 与 WebSocket。
- 20 个 MacCMS Provider：YAML 配置化启停，单源异常不会中断整体搜索。
- 播放列表解析：支持线路 `$$$`、剧集 `#`、标题与 URL `$`。
- MicroDesign：资源搜索结果可生成帖子；资源详情可生成动态海报 `blocks`。
- Flutter 兼容接口：保留 `/api/sources/search` 与 `/api/sources/parse`。

## 2. 关键目录

| 目录 | 用途 |
|---|---|
| `services/resources/` | Provider 配置、MacCMS 适配、并发聚合、播放列表解析 |
| `services/tools/` | Agent 可调用工具；后续 A/B 扩展工具从注册中心追加 |
| `services/llm/` | OpenAI 兼容模型工厂 |
| `services/agent/` | LangChain Agent、会话状态、REST/WS 协议 |
| `services/microdesign/` | 帖子与动态海报 blocks 组合 |

## 3. 本地离线验收

PowerShell 先显式切换 UTF-8：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
cd cine_net_backend
python -m unittest discover -s tests -v
Get-ChildItem -Recurse -Filter *.py | ForEach-Object { python -m py_compile $_.FullName }
```

预期：全部测试通过，编译无报错。测试包含单个 Provider 超时但聚合搜索继续返回的场景。

## 4. 真实资源 smoke

```powershell
cd cine_net_backend
python scripts\smoke_resources.py
```

脚本会真实搜索“星际穿越”，输出：

- 20 个 Provider 中的成功与失败数量；
- 合并后的影视候选；
- 一条成功解析的 HTTP(S) 播放地址；
- `/api/feed`、`/api/poster/{provider_id}/{remote_id}`、`/api/sources/parse` 验收结果。

免费资源站会发生域名失效、限流或证书过期。失败源应出现在 trace 中，但不应拖垮整体检索。

## 5. 配置模型并验收 Agent

复制配置文件：

```powershell
cd cine_net_backend
Copy-Item .env.example .env
```

填写：

```dotenv
LLM_API_KEY=你的聚合站Key
LLM_BASE_URL=https://你的聚合站/v1
LLM_MODEL=聚合站实际模型ID
```

执行：

```powershell
python scripts\smoke_llm.py
```

脚本会验证：

1. 模型调用 `get_backend_status`；
2. 模型调用 `search_playable_resources` 检索“星际穿越”；
3. 返回记录中存在真实 `tool_calls`。

## 6. 启动 FastAPI

```powershell
cd cine_net_backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

打开 `http://127.0.0.1:8000/docs`。

常用接口：

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/api/health` | 后端、LLM 配置、Provider 数量 |
| `GET` | `/api/resources/providers?probe=true` | 实际联网检查 Provider |
| `GET` | `/api/resources/search?keyword=星际穿越` | 多源检索与逐源 trace |
| `GET` | `/api/resources/{provider_id}/{remote_id}` | 资源详情与剧集 |
| `GET` | `/api/feed?keyword=星际穿越` | MicroDesign 帖子 |
| `GET` | `/api/poster/{provider_id}/{remote_id}` | 动态海报 blocks |
| `POST` | `/api/agent/invoke` | Agent REST |
| `WS` | `/ws/chat` | Agent 流式对话 |

## 7. 下一步扩展方式

- 新增标准 MacCMS 源：只改 `services/resources/providers.yaml`。
- 新增垂直资源站：实现独立 Provider，再注册到 `ProviderRegistry`。
- 新增 Agent Tool：在 `services/tools/` 新建工具并追加到 `registry.py`。
- 新增 RAG：作为 Tool 接入，不修改资源聚合内核。
- 新增图片生成：作为 `generate_poster_background` Tool 接入，返回图片资产供 MicroDesign 组合器使用。
