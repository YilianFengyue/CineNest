# 后端 Agent Step 2 验收教程

> 当前范围：在 Step 1 的真实播放资源聚合之上，增加可插拔的豆瓣 + TMDB 影视资料层，并由 Agent 组合出 Flutter 可直接渲染的推荐帖子和动态海报 JSON。

## 1. 这一步解决什么

Step 1 回答“哪里能播放”。Step 2 继续回答“这是什么作品、为什么值得推荐、封面和评分是什么”，然后把两类结果组合起来。

| 分层 | 当前来源 | 用途 |
|---|---|---|
| Catalog 影视资料 | 豆瓣、TMDB | 标题、年份、评分、简介、封面、背景图、类型、演职员 |
| Resource 播放资源 | 20 个 MacCMS 源 | 真实可播放线路、剧集和 m3u8 地址 |
| Recommendation | 后端组合器 | 只保留有播放资源的 Catalog 候选，生成帖子和海报 blocks |
| Agent Tools | LangChain Tool Registry | 让模型按用户意图浏览、搜索、推荐、生成动态海报 |

两个资料源都通过 `services/catalog/providers.yaml` 配置。单个资料源失败只进入 `traces`，不会拖垮整体查询。未填写 TMDB Token 时，豆瓣仍可独立工作。

## 2. TMDB Token 配置

TMDB 官方 API 使用 API Read Access Token 作为 Bearer Token：

1. 登录或注册 TMDB：`https://www.themoviedb.org/signup`
2. 打开账户 API 设置：`https://www.themoviedb.org/settings/api`
3. 按页面提示申请 API 访问权限。
4. 复制较长的 `API Read Access Token`，不是较短的 `API Key`。
5. 在已有的 `cine_net_backend/.env` 中追加：

```dotenv
TMDB_READ_ACCESS_TOKEN=你的API Read Access Token
```

修改 `.env` 后重启 FastAPI。Token 不应提交到 Git。

TMDB 官方说明：

- `https://developer.themoviedb.org/docs/authentication-application`
- `https://developer.themoviedb.org/docs/search-and-query-for-details`

## 3. 配置化启停

编辑 `cine_net_backend/services/catalog/providers.yaml`：

```yaml
providers:
  - id: douban
    enabled: true
  - id: tmdb
    enabled: true
```

- `enabled: false`：禁用对应资料源。
- TMDB 即使保持 `enabled: true`，没有 Token 时也不会参加联网查询。
- 后续新增更多资料源时，实现 Provider 并注册到 `services/catalog/registry.py`，不用改 Agent 主体。

## 4. 新增接口

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/api/catalog/providers` | 查看资料源启用与配置状态 |
| `GET` | `/api/catalog/hot?media_kind=movie` | 聚合热门影视资料 |
| `GET` | `/api/catalog/search?query=星际穿越` | 聚合搜索资料，精确标题优先 |
| `GET` | `/api/catalog/{provider_id}/{source_id}` | 获取资料详情 |
| `GET` | `/api/feed/recommend?query=星际穿越` | 资料候选 + 播放资源联合推荐帖子 |
| `GET` | `/api/poster/catalog/{provider_id}/{source_id}` | 生成 Flutter 动态海报 blocks |

动态海报 JSON 中包含 `banner`、`rating`、`tagRow`、`reason`、`overview`、`videoBar` 等 blocks。Flutter 后续按 `type` 渲染组件即可。

## 5. Agent 可调用的新增 Tools

| Tool | 使用场景 |
|---|---|
| `browse_catalog_hot` | 用户没有指定片名，想看热门内容 |
| `search_catalog_movies` | 用户询问作品资料、封面、评分、简介 |
| `build_recommendation_feed` | 用户需要真实可播放的推荐帖子 |
| `build_catalog_microdesign_poster` | 用户需要某部作品的动态交互海报 |

Agent 只看到稳定的高层 Tools，不直接看到 20 个 MacCMS Provider。播放资源并发、失败隔离和合并由 ResourceAggregator 内部负责。

## 6. 验收命令

PowerShell 显式使用 UTF-8：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:PYTHONIOENCODING = "utf-8"
cd cine_net_backend
```

离线测试与编译：

```powershell
python -m unittest discover -s tests -v
Get-ChildItem -Recurse -Filter *.py | ForEach-Object { python -m py_compile $_.FullName }
git diff --check
```

真实联网 Catalog + Feed + Poster：

```powershell
python scripts\smoke_catalog.py
```

模型自主调度 Catalog 与推荐 Tool：

```powershell
python scripts\smoke_agent_step2.py
```

验收要点：

- `providers` 中豆瓣为 `configured: true`。
- 填好 Token 后 TMDB 为 `configured: true`，并输出 `tmdb_detail`。
- 搜索“星际穿越”时精确标题排在衍生纪录片之前。
- `/api/feed/recommend` 至少返回一个带真实播放地址的帖子。
- `/api/poster/catalog/douban/{id}` 返回动态海报 blocks。
- Agent smoke 两步均出现预期 `tool_calls`。

## 7. 下一步扩展

- 增加豆瓣详情补全与更多 Catalog Provider。
- 接入 B 站、AGE、网盘、本地文件等 Resource Provider。
- 将图片生成模型封装为 Tool，为动态海报生成背景资产。
- Flutter 端按 blocks 协议实现 MicroDesign 组件渲染。
