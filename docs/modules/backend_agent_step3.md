# 后端 Agent Step 3：MicroDesign v1 与 Flutter 联调教程

> 当前状态：后端最终主链已完成。Flutter 可以开始实现动态推荐列表、互动海报详情和聊天气泡内嵌推荐卡片。B站、网盘、本地电影属于后续 Resource Provider 扩展，不阻塞当前联调。

## 1. 人话说明：这一步完成了什么

Step 1 解决“从多个资源站找得到播放地址”。  
Step 2 解决“用豆瓣 + TMDB 补齐评分、封面、简介等资料”。  
Step 3 解决“把这些数据稳定地交给 Flutter 动态渲染，并支持点击交互”。

后端现在返回两类数据：

- `blocks`：告诉 Flutter 页面上依次展示什么组件。
- `actions`：告诉 Flutter 用户点击后执行什么动作。

Flutter 不需要解析 Agent 的自然语言，也不需要知道 20 个资源站怎么并发搜索。它只需要实现有限的 Widget 和 Action 分发器。

## 2. 总体链路

```text
首页推荐：
Flutter -> GET /api/feed/recommend -> MicroDesignPost[]
        -> 渲染 posterRow
        -> 点击 openPoster

互动海报：
Flutter -> GET /api/poster/catalog/{provider_id}/{source_id}
        -> 按 blocks 顺序渲染 banner / rating / tagRow / text / videoBar
        -> 点击 resolveAndPlay

普通播放：
Flutter -> GET /api/sources/parse?source_id=wujin:89203
        -> 拿到 m3u8/mp4
        -> media_kit 直接播放

Agent 对话：
Flutter -> WS /ws/chat
        -> 接收 delta 文本
        -> 接收 attachment 结构化帖子
        -> 在聊天气泡下面复用帖子卡片 Widget
```

## 3. 协议版本

所有 Step 3 帖子、Feed 和互动海报均返回：

```json
{
  "schema_version": "microdesign.v1"
}
```

Flutter 对未知版本应保守降级：显示标题、封面和简介，不执行未知 Action。

## 4. Flutter 需要支持的 Blocks

| Block type | 用途 | 常用字段 |
|---|---|---|
| `posterRow` | 首页和聊天中的紧凑帖子卡片 | `cover`, `score`, `summary`, `tags` |
| `banner` | 互动海报顶部大图 | `image`, `poster`, `title`, `subtitle`, `style` |
| `rating` | 评分 | `score`, `label` |
| `tagRow` | 标签行 | `tags` |
| `heading` | 小标题 | `text` |
| `text` | 推荐理由、简介 | `text` |
| `videoBar` | 可点击播放线路 | `title`, `cover`, `play_url`, `episode_count` |
| `imageSwiper` | 后续剧照或 AI 生图 | `urls` |

注意：当前 Flutter `content_block.dart` 已有多数类型，但还需要由前端补充 `banner` 枚举和 `action` 解析。

## 5. Flutter 需要支持的 Actions

### 5.1 `openPoster`

从 Feed 帖子打开 Catalog 互动海报：

```json
{
  "type": "openPoster",
  "label": "查看互动海报",
  "data": {
    "catalog_provider_id": "douban",
    "catalog_source_id": "1783457",
    "media_kind": "movie"
  }
}
```

Flutter 请求：

```http
GET /api/poster/catalog/douban/1783457?media_kind=movie
```

### 5.2 `openResourcePoster`

旧资源 Feed 没有 Catalog ID 时使用：

```http
GET /api/poster/{provider_id}/{remote_id}
```

### 5.3 `resolveAndPlay`

帖子中的 Action 只有资源站 ID，Flutter 先解析：

```json
{
  "type": "resolveAndPlay",
  "data": {
    "provider_id": "wujin",
    "remote_id": "89203"
  }
}
```

```http
GET /api/sources/parse?source_id=wujin:89203
```

互动海报 `videoBar.action` 已经携带当前线路首集的 `play_url`。Flutter 可以直接交给 `media_kit`，也可以调用 A 的完整资源接口获取选集：

```http
GET /api/resources/wujin/89203
```

## 6. 首页 Feed 接口

```http
GET /api/feed/recommend?query=功夫熊猫&media_kind=movie&limit=3
```

返回摘要：

```json
{
  "schema_version": "microdesign.v1",
  "query": "功夫熊猫",
  "posts": [
    {
      "title": "功夫熊猫",
      "rating": 8.3,
      "source_count": 3,
      "blocks": [
        {"type": "posterRow", "data": {"cover": "...", "score": 8.3}}
      ],
      "actions": [
        {"type": "openPoster", "data": {"catalog_provider_id": "douban", "catalog_source_id": "1783457"}},
        {"type": "resolveAndPlay", "data": {"provider_id": "wujin", "remote_id": "89203"}}
      ]
    }
  ]
}
```

同一查询会在后端缓存 5 分钟，减少首页重复等待多个资源站。

## 7. Agent REST 与 WebSocket

### 7.1 REST

```http
POST /api/agent/invoke
Content-Type: application/json

{
  "thread_id": "user-001",
  "message": "推荐两部功夫熊猫系列，最好能直接播放"
}
```

返回中：

- `answer`：Agent 自然语言回复。
- `tool_calls`：可观测的 Tool 调用记录。
- `attachments`：Flutter 可直接渲染的结构化帖子或海报。

### 7.2 WebSocket

连接：

```text
ws://PC-IP:8000/ws/chat
```

发送：

```json
{"thread_id": "user-001", "message": "推荐两部轻松的动画电影"}
```

事件顺序：

| type | Flutter 行为 |
|---|---|
| `started` | 显示思考中 |
| `tool_started` | 可选：显示正在搜索资料 |
| `tool_finished` | 调试日志，正式 UI 可忽略内容 |
| `attachment` | 将 `data.payload` 渲染为帖子卡片或互动海报 |
| `delta` | 追加 Agent 文本 |
| `done` | 关闭加载态 |
| `error` | 显示友好错误与重试按钮 |

推荐附件格式：

```json
{
  "type": "attachment",
  "data": {
    "type": "recommendation_feed",
    "schema_version": "microdesign.v1",
    "payload": {
      "query": "功夫熊猫",
      "posts": []
    }
  }
}
```

## 8. 模型故障不影响普通播放

聚合站偶发 `502` 时，后端会有限重试，然后返回简短错误：

```text
模型服务暂时不可用（HTTP 502），请稍后重试。
影视资料、推荐 Feed 与播放资源接口仍可正常使用。
```

因此 Flutter 首页和播放器不要强依赖 Agent：

- 首页可直接调用 `/api/feed/recommend`。
- 详情页和播放器直接调用 `/api/resources/*` 或 `/api/sources/*`。
- 聊天页才调用 Agent。

## 9. 验收命令

PowerShell 使用 UTF-8：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:PYTHONIOENCODING = "utf-8"
cd cine_net_backend
```

离线测试：

```powershell
python -m unittest discover -s tests -v
Get-ChildItem -Recurse -Filter *.py | ForEach-Object { python -m py_compile $_.FullName }
git diff --check
```

确定性主链验收，不依赖 LLM：

```powershell
python scripts\smoke_step3.py
```

Agent 调度与附件验收，需要 `.env` 中已配置模型：

```powershell
python scripts\smoke_agent_step3.py
python scripts\smoke_ws_step3.py
```

也可以指定其他影片：

```powershell
python scripts\smoke_step3.py "流浪地球"
python scripts\smoke_agent_step3.py "流浪地球"
python scripts\smoke_ws_step3.py "流浪地球"
```

## 10. 当前明确后置的能力

以下能力不阻塞 Flutter 动态推荐开发，后续作为独立 Provider 或 Tool 增加：

- B站公开视频搜索、登录态、会员取流、弹幕。
- AGE、DM84、aafun 等垂直资源站。
- 百度网盘、Alist、PC 本地视频 Range 流式代理。
- AI 图片生成背景图。
- 用户偏好和历史 SQLite 持久化。
- F12 影视资讯采集。

扩展时保持同一原则：新增 Provider 或 Tool，尽量不改变 Flutter 已接入的 `microdesign.v1` 协议。
