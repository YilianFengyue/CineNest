# CineLink — PC 桌面端完整功能设计书

> 更新：2026-06-12 ｜ 负责人：成员 C ｜ 状态：P1 已完成，P2–P5 待施工
> 仓库：`CodeReference/CineLink`（**独立 git 仓库**，被主仓 gitignore，提交要单独 commit）

---

## 一、定位与架构总览

CineLink 是 CineNest 三件套里的 **PC 桌面伴侣**：

```
┌─────────────┐  扫码/HTTP   ┌──────────────────┐   spawn/探测   ┌──────────────┐
│ CineNest App │ ──────────→ │ FastAPI 后端 :8000 │ ←──────────── │   CineLink    │
│  (Flutter)   │  /api,/ws   │  cine_net_backend │   管理+诊断    │ Electron+Vue │
└─────────────┘             └──────────────────┘               └──────────────┘
                                    ↑ ADB/HDC                        │
                                    └── AutoGLM 手机子 Agent ←───────┘ scrcpy 投屏
```

后端才是算力中心；CineLink 负责把"装 Python、配 .env、查 IP、开 scrcpy"这些命令行苦力活变成图形界面，让后端 **可被一键部署、可被手机找到、可被观察**。

### 技术栈

| 层 | 方案 | 备注 |
|----|------|------|
| 壳 | Electron 41 + electron-builder（nsis） | `yarn electron:dev` 起 dev（vite 端口 4399） |
| 前端 | Vue 3 + Vuetify 3.3 + Pinia | 路由 `src/router/index.ts`，布局 LandingLayout |
| 风格 | lux-ui 同源（同作者库） | `src/styles/common/gradients.scss`、`beautify.scss` 已自带，直接用 `.gradient.primary`、`.card-shadow` |
| IPC | contextBridge 暴露 `window.metaAgent.*` | 类型声明 `src/types/electron.d.ts` |

### 五阶段路线（依赖关系）

| 阶段 | 内容 | 依赖 | 状态 |
|------|------|------|------|
| P1 | 手机扫码连接（LAN + Tailscale） | 无 | ✅ 2026-06-12 |
| P2 | UI 换皮对齐 lux-ui | 无 | 待施工 |
| P3 | 后端管家 BackendManager（启停/诊断/向导） | P1 | 待施工 |
| P4 | ADB / HDC 设备检测 | P3 的进程 IPC | 待施工 |
| P5 | scrcpy 投屏 + Agent 任务监控 | P4 | 待施工 |

---

## 二、现状盘点（写代码前必读）

### CineLink 已有的

- **IPC**：`app:getInfo`、`workspace:*`（文件读写）、`window:*`（窗口控制）、**`net:getInfo` / `net:getTailscale`（P1 新增）**
- **页面**：`DashBoard.vue`（六卡门面）、`PhoneLinkPage.vue`（P1 新增）、其余路由（/backend、/screen-mirror、/agent-console、/network、/library、/settings）全部还指向万能模板页 `CineLinkFeaturePage.vue`，里面是"等待接入 Electron IPC"的占位
- **主题**：`src/plugins/vuetify.ts`——light 主色 `#344767`（灰蓝），dark 主色 `#705CF6`；P2 要动这里

### 后端已有的（CineLink 只管调，不要重复造）

- `GET /api/health` → `{status, service, version, llm_configured, provider_count, ...}`
- `routers/phone.py`：**完整 AutoGLM 任务运行时**，14 个端点 + `WS /ws/tasks` 事件流
  - 任务状态机 8 态：`queued / running / waiting_approval / waiting_takeover / verifying / done / failed / cancelled`
  - `GET /api/phone/devices`（ADB/HDC 设备列表）、`POST /api/phone/tasks`、`/approve`、`/takeover-done`、`/cancel`
  - 配置：`GET/POST /api/phone/config`（运行期改，不写 .env，Key 不回明文）
- `routers/agent.py`：`POST /api/agent/invoke`（LangGraph 主 Agent，会自己调 start_phone_task 派手机任务）
- 启动方式：`uvicorn main:app --host 0.0.0.0 --port 8000`，CORS 全开
- `.env` 关键配置组：`LLM_*`、`TMDB_*`、`PHONE_*`（AutoGLM：`PHONE_ENABLED/PHONE_API_KEY/PHONE_DEVICE_TYPE(adb|hdc)/PHONE_DEVICE_ID/...`）、`IMAGE_*`

### Flutter 端已有的

- F7 连接设置页 `lib/pages/settings/connection_settings_page.dart` + `ConnectionService`（Hive 存 host/port，`Request.updateBaseUrl()` 热切换）
- **P1 新增**：`ScanConnectPage` 扫码页 + `ConnectionService.connectFromQr`

---

## 三、P1 手机连接（已完成 · 实现实录）

### 二维码载荷协议 v1

```json
{"v":1,"app":"cinenest","name":"<PC主机名>","candidates":["http://192.168.x.x:8000","http://100.x.x.x:8000"]}
```

- `candidates` 按当前选中模式排序（局域网优先 or Tailscale 优先）
- 手机端**并发**探测每个候选的 `/api/health`（3s 超时、无重试），按候选**顺序**取第一个连通的
- 无 token / 鉴权（课设演示优先，预留 P3 配置向导加可选 token）

### IPC 契约（已实现）

```ts
window.metaAgent.net.getInfo()
// → { hostname: string, lanIps: [{ address, interfaceName, virtual }] }
//   物理网卡排前（192.168 > 10. > 172.x），剔除 CGNAT 100.64/10（那是 Tailscale 的）

window.metaAgent.net.getTailscale()
// → { installed, running, backendState, ip, hostName, error }
//   依次试 PATH 里的 tailscale 和 C:\Program Files\Tailscale\tailscale.exe，
//   执行 `tailscale status --json`；CLI 找不到时扫网卡 100.64/10 兜底
```

### 文件清单

| 端 | 文件 | 改动 |
|----|------|------|
| CineLink | `electron/main.ts` | + net 区段（getLanIps / getTailscaleStatus / 两个 handler） |
| CineLink | `electron/preload.ts`、`src/types/electron.d.ts` | + net API 暴露与类型 |
| CineLink | `src/views/pages/PhoneLinkPage.vue` | 新建：渐变 hero + 二维码卡 + 双模式卡 + 三步 timeline |
| CineLink | `src/router/index.ts`、`package.json` | /phone-link 指新页；+ qrcode、@types/qrcode |
| Flutter | `lib/services/connection_service.dart` | + `QrLinkPayload.tryParse` + `connectFromQr` |
| Flutter | `lib/pages/settings/scan_connect_page.dart` | 新建：mobile_scanner 扫码页 |
| Flutter | `lib/pages/settings/connection_settings_page.dart` | + 「扫码连接 PC」入口，成功回填表单 |
| Flutter | `pubspec.yaml` | + `mobile_scanner: ^7.1.2`；`material_color_utilities` 改区间 |

### 踩过的坑（明天继续前必看）

1. **`pubspec.yaml` / `pubspec.lock` 被 `git update-index --assume-unchanged` 冻结**（规避组内 Flutter 版本不同互踩 lock）。改依赖必须先 `git update-index --no-assume-unchanged cine_nest_app/pubspec.yaml` 解冻再提交，否则队友编不过。lock 保持冻结、各人本地自己 resolve。
2. **material_color_utilities**：本机 Flutter 3.35.1 内置 0.11.1，队友新 SDK 内置 0.13.0，pubspec 已改 `">=0.11.1 <0.14.0"` 兼容两边，别再写死。
3. **CineLink 装依赖**：dev server 跑着时 `yarn add/install` 会 EPERM 卡在 esbuild.exe（包其实装上了，yarn.lock 没写）。关 dev server 重跑 `yarn install` 补 lock。
4. **改了 electron/main.ts 要重启 dev 实例**才生效（主进程不热载）。

---

## 四、P2 UI 换皮（对齐 lux-ui）

目标：去掉"AI 模板感"，整体视觉对齐 `CodeReference/lux-ui`（同作者，可整搬）。

### 从 lux-ui 抄什么

| 抄什么 | lux-ui 源文件 | 落到 CineLink |
|--------|--------------|---------------|
| 主题色 + defaults | `src/plugins/vuetify.ts`（primary `#705CF6`、VCard rounded lg、VBtn rounded md、grey 50–900 色阶、dark `#22272E/#2B323B`） | 覆写 `src/plugins/vuetify.ts`（light 主色从 `#344767` 换 `#705CF6`，补 grey 色阶和 variables） |
| 柔和阴影体系 | `src/styles/vuetify/_elevations.scss`（umbra 0.08 / penumbra 0.06 / ambient 0.03） | 拷到 `src/styles/vuetify/` 并在 main.scss 引入 |
| 侧边栏骨架 | `components/navigation/MainSidebar.vue`（prepend Logo 卡 + 递归菜单 + append 渐变用户卡） | 改造现有 MainSidebar，底部渐变卡换成"后端状态卡"（在线/离线 + 一键启动入口） |
| 卡片质感 | `components/dashboard/*.vue` 的统计卡/时间线卡 | DashBoard 六卡和后续 P3/P5 面板照此风格 |

### 注意

- 字体**保留 HarmonyOS Sans SC**（CineLink 已配好），不抄 Quicksand——中文渲染 Quicksand 没意义
- `gradients.scss` / `beautify.scss` CineLink 已自带同款，不用搬
- 验收：DashBoard、PhoneLinkPage 在 light/dark 下都协调；侧边栏激活态、卡片 hover 浮起统一

预估文件：`src/plugins/vuetify.ts`、`src/styles/vuetify/_elevations.scss`（新）、`MainSidebar.vue`、`DashBoard.vue` 微调 ≈ 4 个。

---

## 五、P3 后端管家 BackendManager（核心阶段）

目标：`/backend` 页从模板变真功能——**检查、启动、停止、配置、诊断**本地后端。

### 5.1 新增 IPC（`backend:*`，全部走主进程）

```ts
// 环境检查（一次返回全量，前端渲染检查清单）
backend.check(dir: string) → {
  dirOk: boolean,            // 目录存在且有 main.py
  python: { ok, version },   // 先试 <dir>/venv/Scripts/python.exe，再试 PATH 的 python
  venv: boolean,             // venv 目录存在
  deps: boolean,             // venv 里 import fastapi 探测（python -c "import fastapi"）
  envFile: boolean,          // .env 存在
  envKeys: {                 // 只报 已配置/缺失，绝不回明文
    llm: boolean, tmdb: boolean, autoglm: boolean
  },
  portFree: boolean          // 8000 端口占用检测
}

backend.start(payload: { dir, port }) → { pid } | { error }
//  spawn(venv python, ["-m","uvicorn","main:app","--host","0.0.0.0","--port",port], {cwd:dir})
//  stdout/stderr 按行推 "backend:log" 事件到渲染进程（环形缓冲最近 500 行）
backend.stop() → void          // tree-kill（Windows: taskkill /pid /t /f）
backend.getState() → { running, pid, port, startedAt }
backend.onLog(cb)              // 渲染进程订阅日志流
backend.pickDir() → string     // 复用 dialog，记住上次选择（存 userData）
```

判定"后端可用"的唯一标准还是 `GET /api/health`（渲染进程直接 fetch，CORS 全开无障碍），进程在跑 ≠ 服务可用。

### 5.2 页面结构（BackendManagerPage.vue 替换模板页）

```
┌ hero：后端状态总览（运行中 pid/端口/uptime ｜ 已停止）＋ 启动/停止/重启 ┐
├ 左列：环境检查清单（目录/python/venv/依赖/.env/Key×3/端口）每项 ✓/✗/修复建议 │
│       底部「配置向导」按钮 → 六步 v-stepper 弹窗                        │
├ 右列：日志面板（等宽字、自动滚底、暂停滚动、复制全部、清空）              │
└ 底栏：访问地址行——局域网 / Tailscale 地址 + 复制 +「去生成二维码」跳 P1 页 ┘
```

### 5.3 配置向导（v-stepper 六步）

1. 选后端目录（默认猜 `../cine_net_backend` 相对仓库位置）
2. 检查 Python / venv（缺 venv 给出创建命令，可一键执行 `python -m venv venv` + `pip install -r requirements.txt`，日志走同一个面板）
3. 检查 `.env`（不存在则从 `.env.example`/内置模板生成）
4. 填 Key：LLM / TMDB / AutoGLM 三组，输入框 password 型；写入 .env（只追加/替换对应行，不动其他）
5. 启动后端并探测 `/api/health`，显示版本与 `llm_configured`
6. 完成页内嵌 P1 的二维码组件（抽出 `QrPanel.vue` 复用）

预估文件：`electron/main.ts`（backend 区段 ≈150 行）、`preload.ts`、`electron.d.ts`、`BackendManagerPage.vue`（新）、`components/backend/SetupWizard.vue`（新）、`components/backend/LogPanel.vue`（新）、PhoneLinkPage 抽 `QrPanel.vue`、router ≈ 8 个。

---

## 六、P4 ADB / HDC 设备检测

目标：`/screen-mirror` 和 Agent 页都需要的设备底座。

### 双通道策略

| 场景 | 通道 | 说明 |
|------|------|------|
| 后端在跑 | `GET /api/phone/devices` | 后端已实现 ADB/HDC 探测，直接复用 |
| 后端没跑 | Electron 直跑 `adb devices -l` / `hdc list targets` | 新增 `device:list` IPC，找不到 adb 时给 platform-tools 下载指引 |

页面上不区分来源，统一渲染：序列号、型号、连接方式（USB/WiFi）、授权状态（unauthorized 要提示手机上点允许）。

### 新增 IPC

```ts
device.list() → { tool: "adb"|"hdc"|null, devices: [{ id, model, state, transport }] }
device.adbPath() / device.setAdbPath(p)   // 自定义 adb 路径，存 userData
// 预留：device.pair(hostPort, code)  无线调试配对（Android 11+），P4 可选
```

预估文件：`electron/main.ts`（device 区段）、preload/types、`components/device/DeviceList.vue`（新，给 P5 两个页面复用）≈ 4 个。

---

## 七、P5 scrcpy 投屏 + Agent 任务监控

目标：`/screen-mirror` 一个页面 = 左 Agent 控制台 + 右投屏位。

### 7.1 scrcpy（v1 务实方案：独立窗口吸附，不做嵌入）

```ts
mirror.start(opts: { deviceId, maxSize?, bitrate?, alwaysOnTop?: true,
                     windowX?, windowY?, windowWidth?, borderless?: true })
// spawn scrcpy（路径：设置可配，默认试 PATH）
// 参数映射：--serial --max-size --video-bit-rate --window-borderless
//          --always-on-top --window-x --window-y（吸附到 CineLink 窗口右缘外侧）
mirror.stop() / mirror.getState() → { running, pid }
```

- CineLink 窗口 move/resize 时（`mainWindow.on("move")`）重算吸附坐标——scrcpy 不支持运行中移动窗口，v1 只在启动时定位 + 提供「重新吸附」按钮（重启 scrcpy）
- v2 备选：Win32 `SetParent` 真嵌入（koffi/ffi），风险高，**演示效果 v1 已足够，不优先**

### 7.2 Agent 监控面板（左侧）

数据全部来自后端，CineLink 只做展示与操作转发：

- **连接**：`WS /ws/tasks`（任务事件流，与聊天 WS 分离），断线重连
- **渲染**：任务卡（目标、状态 chip 按 8 态配色）＋ 步骤时间线（`task_step` 的 thinking/action，`task_observation` 的屏幕摘要+截图）
- **操作**：
  - `waiting_approval` → 弹确认条 → `POST /api/phone/tasks/{id}/approve`
  - `waiting_takeover` → 提示在投屏窗口里人工操作 → 完成点按钮 `POST .../takeover-done`（**和 scrcpy 是天作之合：接管直接在右边投屏里点**）
  - 取消 → `POST .../cancel`；新任务 → `POST /api/phone/tasks`
- **AutoGLM 配置状态**：`GET /api/phone/config`（enabled/device_type/key 已配置与否）

预估文件：`electron/main.ts`（mirror 区段）、preload/types、`ScreenMirrorPage.vue`（新，含 AgentTaskPanel + DeviceList + 投屏控制）、`components/agent/TaskTimeline.vue`（新）、router ≈ 6 个。

---

## 八、IPC 契约总表

| 命名空间 | 方法 | 状态 |
|----------|------|------|
| `app` / `workspace` / `window` | （原有文件与窗口能力） | ✅ 已有 |
| `net` | `getInfo`、`getTailscale` | ✅ P1 |
| `backend` | `check / start / stop / getState / onLog / pickDir` | P3 |
| `device` | `list / adbPath / setAdbPath`（预留 `pair`） | P4 |
| `mirror` | `start / stop / getState` | P5 |

约定：新 IPC 一律三件套同步改——`electron/main.ts` handler、`electron/preload.ts` 暴露、`src/types/electron.d.ts` 类型；渲染进程判 `window.metaAgent` 可能为 undefined（浏览器预览兜底）。

---

## 九、投屏 Cast v2 + PC 影视库（实现实录 2026-06-12）

> 注意：P2/P3/P5 实际已完成且与上文方案有出入——P5 投屏最终是 **Tango 协议级**
> （`@yume-chan/adb` 连 adb server → 推 scrcpy-server.jar → H.264 → WebCodecs canvas，
> 无声、USB only，定位是 AutoGLM 工作台观察窗），**不是** spawn scrcpy.exe 窗口吸附。

### 9.1 设计原则：手机是大脑，PC 是哑屏幕

在线视频投屏走 **传链接（cast）** 而非屏幕镜像：搜源/解析/选集/弹幕匹配全在手机，
PC（CineLink）只收成品渲染。镜像仅作 cast 播不动时的兜底。

### 9.2 协议 v2（跑在后端 `/ws/pc-control/{room}` 房间广播上，后端零改动）

| 消息 | 方向 | 载荷 |
|------|------|------|
| `hello` | 双向 | `{sender}` 报身份 |
| `load_remote` | 📱→💻 | `{url, headers, title, cover, episodeLabel, position}`（兼容旧 `load`） |
| `danmaku` | 📱→💻 | `{items:[{t秒, text, color, mode}]}` 手机已匹配好的整包 |
| `play/pause/seek/setRate/danmakuToggle/stop` | 📱→💻 | 控制指令 |
| `state` | 💻→📱 | `{position, duration, paused, rate, buffering}` 事件驱动+1s节流 |
| `error` | 💻→📱 | PC 播不动时提示走镜像兜底 |

防盗链关键：hls.js 走 XHR 设不了 Referer/UA，由 Electron 主进程
`session.webRequest.onBeforeSendHeaders` 按 host 注入（IPC `cast:setStreamHeaders`）；
HLS 分片跨 host 时媒体类路径（.m3u8/.ts/.m4s…）兜底注入。

### 9.3 影视库

- 后端：`services/library/`（scanner 文件名解析 + matcher TMDB 匹配，缓存
  `data/library_cache.json` 按 路径+mtime+size 失效）；`GET /api/library` 只读缓存，
  `POST /api/library/scan?force=true` 才打 TMDB；目录运行期可改
  （`/api/library/config`，存 `data/library_config.json` 覆盖 .env）
- 播放仍走 `/api/local-videos/stream/{id}`（HTTP 206 Range）
- CineLink `/library` 海报墙点击 → `castStore.playLocal()` 复用投屏播放器
- 手机 LocalVideosPage 海报墙化，条目 = 本机播放（media_kit 全格式）/ 投屏到 PC

### 9.4 文件清单

| 端 | 文件 | 内容 |
|----|------|------|
| CineLink | `electron/main.ts` | + cast 区段（webRequest 注入），preload/types 同步 |
| CineLink | `src/stores/castStore.ts` | 新建：常驻房间 WS，收 load 自动跳播放页 + `playLocal` |
| CineLink | `src/views/pages/CastPlayerPage.vue` | 新建：hls.js + 弹幕层 + 状态回报 |
| CineLink | `src/components/cast/DanmakuLayer.vue` | 新建：`danmaku` 库 media 模式绑 video |
| CineLink | `src/views/pages/LibraryPage.vue` | 新建：海报墙，替换占位路由 |
| CineLink | `package.json` | + `hls.js` `danmaku`（**dev server 关掉后补 yarn install**） |
| Flutter | `lib/services/cast_service.dart` | 新建：CastChannel/CastLoadPayload/弹幕转线格式 |
| Flutter | `lib/pages/cast/cast_remote_page.dart` | 新建：遥控页（进度/选集/倍速/弹幕开关） |
| Flutter | `kazumi_player_page` + `player_top_bar` + `kazumi_player_view` | 播放器「投屏到 PC」按钮 + 切集解析闭包 |
| Flutter | `lib/pages/local_videos/local_videos_page.dart` | 重做：影视库海报墙 |
| Flutter | `lib/models/library_models.dart`、`api_constants.dart`、路由 | 配套 |
| 后端 | `services/library/{scanner,matcher}.py`、`routers/library.py` | 影视库三件套 |
| 后端 | `services/local_videos.py`、`main.py` | 目录可配 + 挂 router |

### 9.5 已知边界

- CineLink 播本地文件受 Chromium 解码限制（HEVC/10bit mkv 播不了）→ 提示用手机播
- 弹幕开关在手机遥控页；PC 端 overlay 也有本地开关
- 演示网络用手机热点：扫码 LAN 直连、Clash 照常跑（TMDB 刮削不受影响）

---

## 十、明天开工指引（历史，P2/P3 已完成）

1. **先补一次收尾**：关 CineLink dev server → `yarn install` 写入 yarn.lock → 两个仓库各自 commit（主仓暂存区已备好）
2. **推荐顺序 P2 → P3**：P2 半天内能完（4 个文件），换皮后 P3 的新页面直接按新风格写，不用返工
3. P3 是最大单体，先批 5.1 的 IPC 契约再动手；spawn/kill 在 Windows 上注意用 `taskkill /t` 杀进程树，uvicorn 有子进程
4. 所有"检查类"功能渲染端只管画清单，判断逻辑全放主进程，方便后续 CLI 化复用
