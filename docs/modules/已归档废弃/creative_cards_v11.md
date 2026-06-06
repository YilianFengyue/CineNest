# MicroDesign v1.1 富交互卡 · 前端字段契约（C → Codex）

> 前端先落地、Codex 照此改后端。**这些字段是 Flutter widget 真实读取的键**（源：`cine_nest_app/lib/pages/creative/widgets/cards.dart`），不是猜的。
> 后端按 `type` + `data` 下发，Flutter `BlockRenderer` 自动分发渲染。未知 `type` 静默跳过（前向兼容）。

## 0. 区块信封（沿用 v1）

```json
{ "type": "<blockType>", "data": { ... }, "action": { ... } | null }
```

- `data`：自由袋子，各卡读自己关心的键，多给不报错。
- `action`：**单动作**卡用（newsCard / videoExplainCard）。
- **多动作**卡（playableMovieCard 等）把动作放 `data.actions[]`。

### MicroAction（动作，白名单）
```json
{ "type": "openPoster|openResourcePoster|resolveAndPlay", "label": "立即播放", "data": { ... } }
```
- `openPoster` → `data: { catalog_provider_id, catalog_source_id, media_kind }`
- `openResourcePoster` → `data: { provider_id, remote_id }`
- `resolveAndPlay` → `data: { provider_id, remote_id, line_name?, episode_name?, play_url? }`

---

## 1. `playableMovieCard` 可播放电影介绍卡
| 键 | 类型 | 说明 |
|---|---|---|
| `cover` | string | 竖版封面 URL |
| `title` | string | 片名 |
| `year` | string | 年份 |
| `rating` | number | 评分（>0 才显示） |
| `rating_label` | string | 评分来源（豆瓣/TMDB） |
| `summary` | string | 一句话简介/推荐语（≤3 行） |
| `genres` | string[] | 类型标签（取前 3） |
| `source_count` | int | 可用资源数 |
| `actions` | MicroAction[] | 读 `resolveAndPlay`（播放按钮）+ `openPoster`/`openResourcePoster`（整卡点击 + 「查看海报」） |

## 2. `movieCarousel` 电影海报轮播组
| 键 | 类型 | 说明 |
|---|---|---|
| `title` | string | 组标题（可空） |
| `items` | object[] | 每项：`{ cover, title, year?, rating?(number), action?(MicroAction) }` |

## 3. `reviewQuoteCard` 影评引用卡
| 键 | 类型 | 说明 |
|---|---|---|
| `quote` | string | 引用正文（必填） |
| `author` | string | 影评人/作者 |
| `source` | string | 来源（豆瓣影评等） |
| `rating` | number | 该评价的分（>0 显示星） |

## 4. `sourceTraceCard` 来源溯源卡
| 键 | 类型 | 说明 |
|---|---|---|
| `query` | string | 本次检索词 |
| `items` | object[] | 每项：`{ key, label, count?(int), status: "ok"|"empty" }`；`ok` 绿底显计数，`empty` 灰底 |

## 5. `newsCard` 资讯卡（F12）
| 键 | 类型 | 说明 |
|---|---|---|
| `title` | string | 标题（必填） |
| `source` | string | 来源 |
| `published_at` | string | 时间（已格式化的展示串） |
| `summary` | string | 摘要（≤3 行） |
| `cover` | string | 16:9 封面 URL（可空，空则不显示图） |
| `tags` | string[] | 标签 |
| `action`（信封级） | MicroAction | 整卡点击（如打开资讯详情/海报） |

## 6. `mediaGallery` 图集
| 键 | 类型 | 说明 |
|---|---|---|
| `title` | string | 标题（可空） |
| `layout` | string | `"swiper"`(横滑，默认) / `"grid"`(三列网格) |
| `urls` | string[] | 图片 URL 列表 |

## 7. `videoExplainCard` 视频解说卡
| 键 | 类型 | 说明 |
|---|---|---|
| `title` | string | 视频标题 |
| `cover` | string | 16:9 封面 URL |
| `up` | string | UP 主/作者 |
| `duration` | string | 时长（如 `12:36`） |
| `play_count` | string | 播放量（已格式化，如 `48.2 万`） |
| `action`（信封级） | MicroAction | 点击播放（resolveAndPlay / 跳 B 站等） |

---

## 备注给 Codex
- 图片 URL 由后端拼好放进 blocks，手机只显示（前端有兜底，图挂了显占位图标）。
- 事实字段（评分/封面/播放 URL）必须来自真实 Tool，禁止模型编造；卡的「编排+文案」可由 Agent 填。
- 建议新 Tool `build_interactive_answer` 直接产出 `interactive_cards: ContentBlock[]`，WS attachment 增加 `interactive_cards` 类型；前端已能渲染任意上述 block 的数组。
- 前端预览：App 内「对话 → ✨ → 预览交互卡片(mock)」可看全部 7 张卡的设计基准（`card_mock.dart`）。
