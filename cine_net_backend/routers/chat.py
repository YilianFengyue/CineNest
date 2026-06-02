"""AI 对话 WebSocket。"""
from __future__ import annotations

import json
from uuid import uuid4

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from services.agent import stream_agent
from services.agent.schemas import AgentStreamEvent

router = APIRouter(tags=["chat"])


@router.websocket("/ws/chat")
async def chat_ws(ws: WebSocket):
    """流式 Agent 对话。客户端可发送纯文本或 `{message, thread_id}` JSON。"""

    await ws.accept()
    try:
        while True:
            raw = await ws.receive_text()
            try:
                payload = json.loads(raw)
                message = str(payload.get("message", "")).strip()
                thread_id = str(payload.get("thread_id") or uuid4())
            except json.JSONDecodeError:
                message = raw.strip()
                thread_id = str(uuid4())
            if not message:
                await ws.send_json(
                    AgentStreamEvent(type="error", thread_id=thread_id, content="消息不能为空").model_dump()
                )
                continue
            try:
                async for event in stream_agent(message, thread_id):
                    await ws.send_json(event.model_dump())
            except Exception as exc:
                await ws.send_json(
                    AgentStreamEvent(type="error", thread_id=thread_id, content=str(exc)).model_dump()
                )
    except WebSocketDisconnect:
        pass
