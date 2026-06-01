# player —— 成员 A 的领地

**负责功能**：F3 视频播放器 + F4 视频源解析（前端）+ F7 PC 连接设置

## 目录约定（GetX）
```
player/
├── views/         # 播放器页（media_kit）、播放源选择列表、WebView 降级页
├── controllers/   # 播放控制、源切换
└── services/      # 调后端 API（/api/sources/search, /api/sources/parse, /api/bilibili/search）
```

## 接入基建
- 播放器：`media_kit` / `media_kit_video` 已在 pubspec，`MediaKit.ensureInitialized()` 已在 main 调用
- 降级：`flutter_inappwebview` 已就绪
- 连接：`ConnectionService`（已实现）管理 PC 基址与 `/api/health` 测试，设置页 UI 调
  `ConnectionService.to.updateAddress(...)` / `testConnection()`，读 `status` 响应式刷新
- 模型：`lib/models/video_source.dart`
- 路由：预留 `Routes.player / webviewPlayer`

> 开发完成后请在 `docs/modules/player.md` 写功能说明 + 测试结果（见 AGENTS.md）。
