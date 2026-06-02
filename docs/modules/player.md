# 模块开发说明 - Player（成员 A）

## 1. 已完成功能

- [x] F3 视频播放器：使用 `media_kit` 播放 mp4/m3u8/部分 B 站直链，支持播放、暂停、进度拖动、全屏、退出全屏、倍速、加载状态、错误重试和 WebView 降级。
- [x] F4 视频源引擎：后端按 Kazumi 的“规则化视频源”思路拆成 provider 配置和解析引擎，接入 MacCMS JSON 源，并统一返回 `VideoSource`。
- [x] F4 B 站降级：支持 B 站搜索结果展示；当结果是 BV 号时，后端会先尝试解析 B 站直链，失败时前端回退到 WebView。
- [x] F7 PC-手机连接：设置页可输入 PC IP 和端口，保存后测试 `/api/health`，并显示连接中、已连接或失败状态。
- [x] 成员 A 验收入口：设置页保留搜索电影、选择视频源、解析并播放的测试区域；固定 demo 视频只作为播放器测试按钮，不再混入真实搜索结果。

## 2. 涉及文件

| 文件 | 作用 |
|---|---|
| `cine_nest_app/lib/pages/player/views/player_page.dart` | 正式播放器页面 |
| `cine_nest_app/lib/pages/player/views/webview_player_page.dart` | WebView 降级页面 |
| `cine_nest_app/lib/pages/player/views/source_debug_panel.dart` | 成员 A 真机验收入口 |
| `cine_nest_app/lib/pages/player/services/source_api_service.dart` | 前端视频源 API 封装和本地降级 |
| `cine_nest_app/lib/pages/main/main_app.dart` | 设置页 PC 连接配置 UI |
| `cine_nest_app/lib/router/app_pages.dart` | 注册 `/player` 和 `/webview-player` |
| `cine_nest_app/android/app/src/main/AndroidManifest.xml` | 真机网络权限和开发期 HTTP 明文访问 |
| `fastApiProject1/routers/sources.py` | 成员 A API 路由 |
| `fastApiProject1/services/video_engine/engine.py` | MacCMS/Bilibili/demo 视频源解析引擎 |
| `fastApiProject1/services/video_engine/providers.json` | MacCMS 源配置 |

## 3. 关键接口

```http
GET /api/health
GET /api/sources/search?movie_name=肖申克的救赎
GET /api/sources/parse?source_id=maccms:<provider_id>:<vod_id>
GET /api/sources/parse?source_id=bili:<bvid>
GET /api/bilibili/search?keyword=肖申克的救赎 解说
```

`source_id` 格式：

- `maccms:<provider_id>:<vod_id>`：真实 MacCMS 视频源。
- `demo:<keyword>`：固定 demo 播放源，只用于播放器稳定性验收。
- `bili:<keyword>`：B 站搜索页 WebView 降级源。
- `bili:<bvid>`：B 站视频页，后端优先尝试解析直链，失败后前端降级 WebView。

## 4. 真机验收步骤

1. 在 PyCharm 打开 `D:\AndoridProject\fastApiProject1`，运行：

   ```powershell
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

2. 在电脑命令行执行 `ipconfig`，找到和手机同一 Wi-Fi 下的 IPv4 地址，例如 `192.168.1.100`。
3. Android Studio 打开 `D:\AndoridProject\CineNest-master\CineNest-master\cine_nest_app`，重新运行 App。
4. 进入底部“Settings”，填写 PC IP 和端口 `8000`，点击保存并测试连接。
5. 状态显示已连接后，在成员 A 视频源验收区输入电影名，例如“肖申克的救赎”。
6. 点击搜索视频源：
   - MacCMS 源命中时，点击后会解析播放地址，直链进入播放器，网页源进入 WebView。
   - B 站结果命中时，点击后会先尝试直链播放，失败则打开 B 站移动网页。
   - 如果外部资源站没有命中，可点击固定 demo 按钮验证播放器功能。
7. 在播放器中验收播放、暂停、进度拖动、倍速、全屏、退出全屏、错误重试和 WebView 降级。

## 5. 已知限制

- 免费 MacCMS 源稳定性不由项目控制，可能出现源失效、广告片、名称不匹配或网络慢。
- B 站直链解析不使用 cookie；如果 B 站接口限制或防盗链生效，会自动回退 WebView。
- 当前播放器满足成员 A 验收要求；后续可继续参考 Kazumi 增加更完整的手势控制、弹幕、清晰度选择和播放历史。
