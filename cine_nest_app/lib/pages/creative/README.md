# creative —— 成员 C 的领地

**负责功能**：F8 Micro Design 海报 + F9 AI 对话 + F12 影视资讯

## 目录约定（GetX）
```
creative/
├── views/         # 对话页（聊天 UI + WebSocket）、资讯 Tab、海报展示组件
├── controllers/   # 对话状态、资讯列表
└── services/      # 调后端 API（/api/poster/{id}, /api/news, WebSocket /ws/chat）
```

## 接入基建
- 网络：REST 走 `Request()`；WebSocket 用 `ApiConstants.wsChat` 自行建连
- 海报：帖子卡片的 `Post.posterUrl` 指向 C 的 `/api/poster/{movie_id}`，为空时回退 `movie.posterUrl`
- 图片：`cached_network_image` 已就绪
- 对话推荐结果点击 → 跳成员 B 的 `Routes.movieDetail`

> 开发完成后请在 `docs/modules/creative.md` 写功能说明 + 测试结果（见 AGENTS.md）。
