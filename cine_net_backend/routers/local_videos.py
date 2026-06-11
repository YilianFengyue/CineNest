from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, StreamingResponse

from models.schemas import LocalVideo
from services.local_videos import (
    decode_video_id,
    guess_video_mime,
    iter_file_range,
    list_local_videos,
)


router = APIRouter(tags=["local-videos"])


class PcControlRooms:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}

    async def connect(self, room_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self._rooms.setdefault(room_id, set()).add(websocket)

    def disconnect(self, room_id: str, websocket: WebSocket) -> None:
        peers = self._rooms.get(room_id)
        if peers is None:
            return
        peers.discard(websocket)
        if not peers:
            self._rooms.pop(room_id, None)

    async def broadcast(self, room_id: str, payload: dict[str, Any]) -> None:
        dead: list[WebSocket] = []
        for peer in list(self._rooms.get(room_id, set())):
            try:
                await peer.send_text(json.dumps(payload, ensure_ascii=False))
            except Exception:  # noqa: BLE001
                dead.append(peer)
        for peer in dead:
            self.disconnect(room_id, peer)


rooms = PcControlRooms()


@router.get("/api/local-videos", response_model=list[LocalVideo])
async def get_local_videos() -> list[LocalVideo]:
    return list_local_videos()


@router.post("/api/local-videos/rescan", response_model=list[LocalVideo])
async def rescan_local_videos() -> list[LocalVideo]:
    return list_local_videos()


@router.get("/api/local-videos/stream/{video_id}")
async def stream_local_video(video_id: str, range_header: str | None = Header(default=None, alias="Range")):
    path = decode_video_id(video_id)
    file_size = path.stat().st_size
    media_type = guess_video_mime(path)

    start = 0
    end = file_size - 1
    status_code = 200
    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(file_size),
        "Content-Type": media_type,
    }

    if range_header:
        start, end = _parse_range(range_header, file_size)
        status_code = 206
        headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"
        headers["Content-Length"] = str(end - start + 1)

    return StreamingResponse(
        iter_file_range(path, start, end),
        status_code=status_code,
        media_type=media_type,
        headers=headers,
    )


def _parse_range(value: str, file_size: int) -> tuple[int, int]:
    if not value.startswith("bytes="):
        raise HTTPException(status_code=416, detail="Invalid Range header")
    raw_start, _, raw_end = value.removeprefix("bytes=").partition("-")
    if not raw_start:
        length = int(raw_end or "0")
        start = max(0, file_size - length)
        end = file_size - 1
    else:
        start = int(raw_start)
        end = int(raw_end) if raw_end else file_size - 1
    if start < 0 or end >= file_size or start > end:
        raise HTTPException(status_code=416, detail="Requested range not satisfiable")
    return start, end


@router.get("/pc-player", response_class=HTMLResponse)
async def pc_player(room: str = "default") -> str:
    return _pc_player_html(room)


@router.websocket("/ws/pc-control/{room_id}")
async def pc_control(websocket: WebSocket, room_id: str):
    await rooms.connect(room_id, websocket)
    await rooms.broadcast(room_id, {"type": "peer", "message": "connected", "room": room_id})
    try:
        while True:
            text = await websocket.receive_text()
            try:
                payload = json.loads(text)
            except json.JSONDecodeError:
                payload = {"type": "raw", "value": text}
            await rooms.broadcast(room_id, payload)
    except WebSocketDisconnect:
        rooms.disconnect(room_id, websocket)
        await rooms.broadcast(room_id, {"type": "peer", "message": "disconnected", "room": room_id})


def _pc_player_html(room: str) -> str:
    safe_room = json.dumps(room)
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>CineNest PC Player</title>
  <style>
    body {{ margin: 0; background: #101014; color: #f8f7ff; font-family: system-ui, sans-serif; }}
    header {{ padding: 16px 20px; display: flex; gap: 16px; align-items: center; background: #191725; }}
    video {{ width: 100vw; height: calc(100vh - 104px); background: #000; display: block; }}
    .pill {{ padding: 6px 12px; border-radius: 999px; background: #695d93; }}
    .muted {{ color: #cfc9df; }}
  </style>
</head>
<body>
  <header>
    <strong>CineNest PC Player</strong>
    <span class="pill">Room: <span id="room"></span></span>
    <span id="status" class="muted">connecting...</span>
    <span id="title" class="muted"></span>
  </header>
  <video id="video" controls playsinline></video>
  <script>
    const room = {safe_room};
    const video = document.getElementById('video');
    const statusEl = document.getElementById('status');
    const titleEl = document.getElementById('title');
    document.getElementById('room').textContent = room;
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${{protocol}}//${{location.host}}/ws/pc-control/${{encodeURIComponent(room)}}`);
    ws.onopen = () => statusEl.textContent = 'connected';
    ws.onclose = () => statusEl.textContent = 'disconnected';
    ws.onmessage = async (event) => {{
      const msg = JSON.parse(event.data);
      if (msg.sender === 'pc') return;
      if (msg.type === 'load') {{
        titleEl.textContent = msg.title || '';
        video.src = msg.url;
        video.load();
        if (msg.autoplay !== false) await video.play().catch(() => {{}});
      }}
      if (msg.type === 'play') await video.play().catch(() => {{}});
      if (msg.type === 'pause') video.pause();
      if (msg.type === 'seek') video.currentTime = Number(msg.position || 0);
      if (msg.type === 'setRate') video.playbackRate = Number(msg.rate || 1);
    }};
    setInterval(() => {{
      if (ws.readyState === WebSocket.OPEN) {{
        ws.send(JSON.stringify({{
          sender: 'pc',
          type: 'state',
          position: video.currentTime,
          duration: video.duration || 0,
          paused: video.paused,
          rate: video.playbackRate,
        }}));
      }}
    }}, 1000);
  </script>
</body>
</html>"""
