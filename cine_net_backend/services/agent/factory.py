"""LangChain v1 Agent Core。"""
from __future__ import annotations

import json
from functools import lru_cache
from typing import Any, AsyncIterator

from langchain.agents import create_agent
from langchain_core.messages import AIMessage, BaseMessage, ToolMessage
from langgraph.checkpoint.memory import InMemorySaver

from services.llm import get_chat_model
from services.tools import get_agent_tools

from .schemas import AgentAttachment, AgentInvokeResponse, AgentStreamEvent

_ATTACHMENT_TYPES = {
    "build_recommendation_feed": "recommendation_feed",
    "build_catalog_microdesign_poster": "microdesign_poster",
}


class AgentServiceUnavailableError(RuntimeError):
    """模型聚合站暂时不可用；确定性 REST 接口仍可继续使用。"""

SYSTEM_PROMPT = """\
你是 CineNest 的影视策展 Agent。
你的回答必须基于工具返回的真实数据，不得编造影视资料、评分、资源站、播放 URL 或剧集。
影视资料优先通过 Catalog 工具查询豆瓣/TMDB；播放可用性通过 Resource 工具确认。
当用户需要推荐帖子时调用 build_recommendation_feed；需要动态海报时调用 build_catalog_microdesign_poster。
用户明确要找播放地址时，调用 search_playable_resources 与 get_playable_resource_detail。
工具字段为空时必须明确说“暂无”，不得用模型记忆补充简介、剧情、演职员、评分、封面或播放信息。
如果工具没有返回结果，明确告诉用户暂未检索到，不要用常识补造任何影视资料或播放线路。
回答使用简洁中文，并说明本次实际检索到的资源情况。
"""


def _config(thread_id: str) -> dict[str, dict[str, str]]:
    return {"configurable": {"thread_id": thread_id}}


def _message_text(message: BaseMessage) -> str:
    content = message.content
    if isinstance(content, str):
        return content
    return str(content)


def _collect_tool_calls(messages: list[BaseMessage]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for message in messages:
        if isinstance(message, AIMessage):
            calls.extend(message.tool_calls)
    return calls


def _attachment_from_tool_message(message: ToolMessage) -> AgentAttachment | None:
    attachment_type = _ATTACHMENT_TYPES.get(message.name or "")
    if attachment_type is None:
        return None
    try:
        payload = json.loads(_message_text(message))
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    return AgentAttachment(
        type=attachment_type,
        schema_version=str(payload.get("schema_version") or "microdesign.v1"),
        payload=payload,
    )


def _collect_attachments(messages: list[BaseMessage]) -> list[AgentAttachment]:
    attachments: list[AgentAttachment] = []
    for message in messages:
        if isinstance(message, ToolMessage):
            attachment = _attachment_from_tool_message(message)
            if attachment is not None:
                attachments.append(attachment)
    return attachments


def _friendly_upstream_error(exc: Exception) -> AgentServiceUnavailableError | None:
    status_code = getattr(exc, "status_code", None)
    module_name = type(exc).__module__
    if status_code is None and not module_name.startswith(("openai", "httpx")):
        return None
    status_hint = f"（HTTP {status_code}）" if status_code is not None else ""
    return AgentServiceUnavailableError(
        f"模型服务暂时不可用{status_hint}，请稍后重试。影视资料、推荐 Feed 与播放资源接口仍可正常使用。"
    )


@lru_cache(maxsize=1)
def get_cine_agent():
    """懒加载 Agent；没有 Key 时资源 REST 接口仍然可用。"""

    return create_agent(
        model=get_chat_model(),
        tools=get_agent_tools(),
        system_prompt=SYSTEM_PROMPT,
        checkpointer=InMemorySaver(),
        name="cinenest_agent",
    )


async def invoke_agent(message: str, thread_id: str) -> AgentInvokeResponse:
    try:
        result = await get_cine_agent().ainvoke(
            {"messages": [{"role": "user", "content": message}]},
            config=_config(thread_id),
        )
    except Exception as exc:
        friendly = _friendly_upstream_error(exc)
        if friendly is None:
            raise
        raise friendly from exc
    messages = result["messages"]
    return AgentInvokeResponse(
        thread_id=thread_id,
        answer=_message_text(messages[-1]),
        tool_calls=_collect_tool_calls(messages),
        attachments=_collect_attachments(messages),
    )


async def stream_agent(message: str, thread_id: str) -> AsyncIterator[AgentStreamEvent]:
    """把 LangChain 更新转换为稳定的 WebSocket 事件。"""

    yield AgentStreamEvent(type="started", thread_id=thread_id)
    try:
        async for update in get_cine_agent().astream(
            {"messages": [{"role": "user", "content": message}]},
            config=_config(thread_id),
            stream_mode="updates",
        ):
            for node_name, payload in update.items():
                messages = payload.get("messages", []) if isinstance(payload, dict) else []
                for current in messages:
                    if isinstance(current, ToolMessage):
                        yield AgentStreamEvent(
                            type="tool_finished",
                            thread_id=thread_id,
                            data={"tool_name": current.name or node_name, "content": _message_text(current)},
                        )
                        attachment = _attachment_from_tool_message(current)
                        if attachment is not None:
                            yield AgentStreamEvent(
                                type="attachment",
                                thread_id=thread_id,
                                data=attachment.model_dump(),
                            )
                    elif isinstance(current, AIMessage):
                        for call in current.tool_calls:
                            yield AgentStreamEvent(type="tool_started", thread_id=thread_id, data=call)
                        text = _message_text(current)
                        if text:
                            yield AgentStreamEvent(type="delta", thread_id=thread_id, content=text)
    except Exception as exc:
        friendly = _friendly_upstream_error(exc)
        if friendly is None:
            raise
        raise friendly from exc
    yield AgentStreamEvent(type="done", thread_id=thread_id)
