# feed —— 成员 B 的领地

**负责功能**：F1 帖子流 + F2 详情页 + F6 用户偏好（前端部分）

## 目录约定（GetX）
```
feed/
├── views/         # 首页帖子流、电影详情页、偏好设置页、观影历史页
├── controllers/   # GetxController（状态 + 业务）
└── services/      # 调后端 API（/api/feed, /api/movie/{id}, /api/preferences, /api/feedback）
```

## 接入基建
- 网络：`Request().get(ApiConstants.feed)` → 返回 `LoadingState<List<Post>>`
- 模型：`lib/models/post.dart`、`movie.dart`、`user_preference.dart`
- 路由：在 `lib/router/app_routes.dart` 已预留 `Routes.movieDetail / preference / history`，
  页面写好后在 `lib/router/app_pages.dart` 的 `getPages` 追加 `GetPage`。
- 偏好持久化：`GStorage.localCache` + `LocalCacheKey.userPreference`

> 开发完成后请在 `docs/modules/feed.md` 写功能说明 + 测试结果（见 AGENTS.md）。
