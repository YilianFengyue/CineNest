"""AI 对话 WebSocket。"""
from __future__ import annotations

import json
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from services.assets.models import AgentInputAttachment
from services.agent import stream_agent
from services.agent.schemas import AgentStreamEvent
from services.chat import add_message, delete_session, get_history, list_sessions, rename_session
from services.chat.models import ChatHistoryResponse, ChatSession
from services.memory import remember_chat_signal

router = APIRouter(tags=["chat"])


class RenameSessionRequest(BaseModel):
    title: str


@router.get("/api/chat/sessions", response_model=list[ChatSession])
async def chat_sessions(limit: int = Query(50, ge=1, le=200)) -> list[ChatSession]:
    """列出聊天会话。"""

    return list_sessions(limit=limit)


@router.get("/api/chat/sessions/{thread_id}/messages", response_model=ChatHistoryResponse)
async def chat_messages(thread_id: str) -> ChatHistoryResponse:
    """读取某个会话的聊天历史。"""

    try:
        return get_history(thread_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.patch("/api/chat/sessions/{thread_id}", response_model=ChatSession)
async def update_chat_session(thread_id: str, payload: RenameSessionRequest) -> ChatSession:
    """重命名会话。"""

    try:
        return rename_session(thread_id, payload.title.strip()[:80] or "未命名会话")
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/api/chat/sessions/{thread_id}")
async def remove_chat_session(thread_id: str) -> dict:
    """删除会话和本地聊天记录。"""

    delete_session(thread_id)
    return {"ok": True}


@router.websocket("/ws/chat")
async def chat_ws(ws: WebSocket):
    """流式 Agent 对话。客户端可发送纯文本或 `{message, thread_id, model, attachments}` JSON。"""

    await ws.accept()
    try:
        while True:
            raw = await ws.receive_text()
            try:
                payload = json.loads(raw)
                message = str(payload.get("message", "")).strip()
                thread_id = str(payload.get("thread_id") or uuid4())
                model = str(payload.get("model") or "default")
                attachments = [
                    AgentInputAttachment.model_validate(item)
                    for item in payload.get("attachments") or []
                    if isinstance(item, dict)
                ]
            except json.JSONDecodeError:
                message = raw.strip()
                thread_id = str(uuid4())
                model = "default"
                attachments = []
            if not message:
                await ws.send_json(
                    AgentStreamEvent(type="error", thread_id=thread_id, content="消息不能为空").model_dump()
                )
                continue
            try:
                add_message(
                    thread_id,
                    "user",
                    message,
                    model=model,
                    attachments=[item.model_dump() for item in attachments],
                )
                remember_chat_signal("default", message)
                assistant_parts: list[str] = []
                assistant_attachments: list[dict] = []
                tool_calls: list[dict] = []
                async for event in stream_agent(message, thread_id, model=model, attachments=attachments):
                    if event.type == "delta" and event.content:
                        assistant_parts.append(event.content)
                    elif event.type == "attachment":
                        assistant_attachments.append(event.data)
                    elif event.type == "tool_started":
                        tool_calls.append(event.data)
                    await ws.send_json(event.model_dump())
                add_message(
                    thread_id,
                    "assistant",
                    "\n".join(assistant_parts).strip(),
                    model=model,
                    attachments=assistant_attachments,
                    tool_calls=tool_calls,
                )
            except Exception as exc:
                add_message(thread_id, "system", str(exc), model=model)
                await ws.send_json(
                    AgentStreamEvent(type="error", thread_id=thread_id, content=str(exc)).model_dump()
                )
    except WebSocketDisconnect:
        pass
