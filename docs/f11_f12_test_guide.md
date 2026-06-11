# F11 + F12 真机测试流程

## 1. 后端准备

1. 把测试视频放到 `d:\FLutter\HarmonyOs\CineNest\LocalVideos`。
   - 支持：`mp4`、`mkv`、`mov`、`webm`、`m3u8`、`avi`。
   - 可以放子文件夹，后端会递归扫描。
2. 打开 PyCharm 或终端，进入后端目录：
   `d:\FLutter\HarmonyOs\CineNest\cine_net_backend`
3. 启动命令：
   ```powershell
   .\.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
4. 电脑浏览器访问：
   `http://127.0.0.1:8000/api/health`
   - 看到 `ok` 或健康检查 JSON，说明后端启动成功。
5. 用 `ipconfig` 查看电脑 IPv4，例如 `192.168.43.130`。

## 2. 手机连接后端

1. 手机和电脑连接同一个 Wi-Fi。
2. 打开 App，进入 `Settings`。
3. 在 `PC backend connection` 输入电脑 IPv4 和端口 `8000`。
4. 点击 `Save and test`。
5. 看到 `Connected` 或已连接，说明手机能访问后端。

## 3. F11：手机播放 PC 本地视频

1. 进入 `Settings`。
2. 点击 `PC 本地视频库 / 投屏控制`。
3. 页面应显示 `d:\FLutter\HarmonyOs\CineNest\LocalVideos` 下的视频列表。
4. 如果刚放入视频没有显示，点击右上角刷新。
5. 点击某个视频的 `Play on phone`。
6. 应进入播放器，并播放电脑本地视频。
7. 验收播放/暂停、进度条、倍速、全屏、退出全屏。

## 4. F11：投到 PC 浏览器并用手机遥控

1. 在 `PC 本地视频库 / 投屏控制` 页面查看 `Open on PC browser` 后面的地址。
2. 在电脑浏览器打开这个地址，例如：
   `http://电脑IP:8000/pc-player?room=cinenest`
3. 回到手机，点击某个视频的 `Cast to PC`。
4. 手机进入 `PC remote control` 页面。
5. 手机页面顶部会同步播放同一个视频，电脑浏览器也应自动加载并播放该视频。
6. 在手机上测试：
   - `Play`：手机和电脑同时开始播放。
   - `Pause`：手机和电脑同时暂停。
   - `-10s` / `+10s`：手机和电脑视频一起快退/快进。
   - `1.0x / 1.25x / 1.5x / 2.0x`：手机和电脑播放倍速一起变化。
7. 手机页面的 `PC state` 会显示电脑当前播放/暂停和进度。

## 5. F12：口味 DNA

1. 进入 `Settings`。
2. 点击顶部 `口味 DNA` 卡片。
3. 页面会显示：
   - 口味总结。
   - 类型比例。
   - 心情标签。
   - 规避类型。
   - 可信度。
4. 如果画像不准，先回到口味偏好页面，在 Like 里选几个喜欢类型，再保存。
5. 再回到 `口味 DNA` 页面，点击刷新。
6. 类型比例和总结应该根据新的偏好变化。

## 6. F12：AI Q 版画像生成

1. 确认后端 `.env` 配置了 `IMAGE_API_KEY` 或 `LLM_API_KEY`。
2. 进入 `Settings` -> `口味 DNA`。
3. 点击 `Generate Q avatar`。
4. 成功时会显示一张 AI 生成的 Q 版观影画像。
5. 如果没有配置 Key，页面会显示明确错误，例如 AI 图片服务未配置。
6. 同一份口味画像生成过后会缓存；再次进入页面会直接显示最近一次图片。

## 7. 常见问题

- 手机连接失败：确认手机和电脑同 Wi-Fi，电脑防火墙允许 8000 端口，后端启动命令包含 `--host 0.0.0.0`。
- 本地视频列表为空：确认视频确实放在 `d:\FLutter\HarmonyOs\CineNest\LocalVideos`，扩展名受支持，然后点刷新。
- 手机播放失败：先用电脑浏览器访问 `/api/local-videos` 看列表是否正常，再确认手机连接的 PC IP 正确。
- PC 投屏无反应：确认电脑浏览器打开的是手机页面显示的同一个 room 地址，例如 `room=cinenest`。
- AI 画像失败：检查 `.env` 中 `IMAGE_API_KEY` 或 `LLM_API_KEY`，以及梯子/额度是否正常。
