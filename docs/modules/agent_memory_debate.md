# Agent 长期记忆与辩论式推荐模块

## 范围

- F16：PC 后端保存 Flutter 本地观看历史、收藏与对话偏好信号，生成可视化用户画像。
- F17：一次 LLM 调用模拟“影视推荐委员会”，输出口味官、资源官、口碑官、反方官与主推荐官结论。

## 后端接口

### POST `/api/agent/memory/sync`

Flutter 将本地 `LocalHistoryRepository.exportJson()` 与 `LocalFavoriteRepository.exportJson()` 解析成数组后上报。

```json
{
  "user_id": "default",
  "device_id": "flutter",
  "exported_at": 1710000000000,
  "history": [],
  "favorites": []
}
```

返回同步批次、接收数量、去重新增数量和画像更新时间。

### GET `/api/agent/profile?user_id=default`

返回前端可直接渲染的画像数据：

- `summary`：画像摘要
- `taste_tags` / `avoid_tags`：标签云
- `source_distribution` / `format_distribution`：分布图
- `radar_metrics`：雷达图指标
- `graph_nodes` / `graph_edges`：关系图
- `timeline`：时间轴
- `stats`：计数与调试信息

### POST `/api/agent/profile/rebuild`

从长期记忆重建画像。

```json
{"user_id": "default", "use_llm": false}
```

### POST `/api/agent/debate/recommend`

生成“AI 推荐委员会结论”。

F17 当前固定使用后端 `.env` 的默认 LLM：

- `LLM_BASE_URL=https://api.vveai.com/v1`
- `LLM_MODEL=gemini-3.1-pro-preview`

这里不跟 Chat 页模型选择联动，避免播放器评论区的演示链路被其它模型别名影响。

```json
{
  "user_id": "default",
  "movie": "星际穿越",
  "year": "2014",
  "overview": "父亲穿越虫洞寻找新家园。",
  "source_name": "本地聚合源",
  "episode_name": "正片",
  "playable": true,
  "rating": "8.9",
  "tags": ["科幻", "剧情"]
}
```

返回 `result`：

- `taste_agent`
- `resource_agent`
- `review_agent`
- `critic_agent`
- `chair_agent`
- `final_score`
- `final_reason`
- `risk_tips`
- `highlight_moments`
- `render_sections`
- `recommend`

LLM 不可用时会返回 `generated_by=fallback` 的确定性结果，方便课堂演示不断线。

`render_sections` 是播放器评论区的渲染协议：

- `hot_comments`：评论列表，包含 `author`、`badge`、`content`、`likes`、`reply_preview`
- `highlight_buttons`：精彩片段按钮，包含 `label`、`why`、`button_text`、`action`
- `danmaku_seeds`：弹幕种子文案，可用于播放器上方弹幕氛围

精彩片段按钮的 `action` 当前约定：

```json
{
  "type": "seek_or_hint",
  "label": "开场设定段",
  "approx_time": "",
  "start_ms": null,
  "episode_index": 0
}
```

没有真实字幕/章节/时间轴时，后端不会硬编 `start_ms`；前端应展示提示或片段说明。以后接入真实切片数据后，再把 `start_ms/end_ms` 填实并接播放器 seek。

## 前端入口

- 设置页：`Agent 长期画像`
  - 同步本地历史/收藏到后端
  - 查看画像摘要、标签、雷达指标、片源分布、时间轴
- Kazumi 播放页：评论 Tab
  - 点击“生成委员会结论”
  - 展示四个专家意见、主推荐官、风险提示和精彩片段

## 数据表

- `agent_sync_batches`：同步批次
- `agent_memory_items`：长期记忆事件
- `agent_profile`：画像快照
- `agent_memory_edges`：画像关系图边

## 验收建议

1. 播放几部影片并收藏至少一部。
2. 设置页进入 Agent 长期画像，点击同步。
3. 确认 `taste_tags`、`radar_metrics`、`timeline` 有数据。
4. 进入任意播放页评论 Tab，点击生成委员会结论。
5. 后端无 Key 时也应返回 fallback 结构，前端卡片不空白。
