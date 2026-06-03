"""LangChain v1 Agent Core。"""
from __future__ import annotations

import json
from typing import Any, AsyncIterator

from langchain.agents import create_agent
from langchain_core.messages import AIMessage, BaseMessage, ToolMessage
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from config import settings
from services.assets import AgentInputAttachment, asset_data_url, get_asset
from services.llm import get_chat_model
from services.tools import get_agent_tools

from .schemas import AgentAttachment, AgentInvokeResponse, AgentStreamEvent

_ATTACHMENT_TYPES = {
    "build_recommendation_feed": "recommendation_feed",
    "build_catalog_microdesign_poster": "microdesign_poster",
    "build_interactive_answer": "interactive_cards",
    "collect_movie_news": "news_feed",
    "generate_movie_news": "news_feed",
}


class AgentServiceUnavailableError(RuntimeError):
    """模型聚合站暂时不可用；确定性 REST 接口仍可继续使用。"""


_CHECKPOINTER_CONTEXT: Any | None = None
_CHECKPOINTER: AsyncSqliteSaver | None = None
_AGENTS: dict[str, Any] = {}

SYSTEM_PROMPT = """\
你是 CineNest 的影视策展 Agent。
你的回答必须基于工具返回的真实数据，不得编造影视资料、评分、资源站、播放 URL 或剧集。
影视资料优先通过 Catalog 工具查询豆瓣/TMDB；播放可用性通过 Resource 工具确认。
当用户需要推荐帖子时调用 build_recommendation_feed；需要动态海报时调用 build_catalog_microdesign_poster。
当用户在聊天中需要可点击卡片、电影轮播、评价卡或“像 ChatGPT 一样的交互回答”时，优先调用 build_interactive_answer。
当用户询问影视资讯、热点、新闻或资讯页内容时，调用 collect_movie_news。
当用户要求“为某部电影生成资讯/特辑/海报资讯”时，调用 generate_movie_news（会生成 AI 海报图并持久化到资讯列表）。
做电影推荐时优先用富媒体卡片（build_interactive_answer），让回答更直观、可点击、可播放。
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
        schema_version=str(payload.get("schema_version") or "microdesign.v1.1"),
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


async def _get_sqlite_checkpointer() -> AsyncSqliteSaver:
    """LangGraph 异步 SQLite 持久化 checkpointer。"""

    global _CHECKPOINTER_CONTEXT, _CHECKPOINTER
    if _CHECKPOINTER is not None:
        return _CHECKPOINTER
    settings.agent_checkpoint_db_path.parent.mkdir(parents=True, exist_ok=True)
    _CHECKPOINTER_CONTEXT = AsyncSqliteSaver.from_conn_string(str(settings.agent_checkpoint_db_path))
    saver = await _CHECKPOINTER_CONTEXT.__aenter__()
    await saver.setup()
    _CHECKPOINTER = saver
    return saver


def _message_payload(message: str, attachments: list[AgentInputAttachment] | None = None):
    attachments = attachments or []
    if not attachments:
        return message
    content: list[dict[str, Any]] = [{"type": "text", "text": message}]
    file_notes: list[str] = []
    for item in attachments:
        try:
            record = get_asset(item.asset_id)
        except LookupError:
            file_notes.append(f"未找到上传资产 {item.asset_id}")
            continue
        if record.kind == "image":
            content.append({"type": "image_url", "image_url": {"url": asset_data_url(record)}})
        else:
            file_notes.append(f"用户上传了文件 {record.filename}（{record.mime}），当前已存档，后续可进入 RAG。")
    if file_notes:
        content.append({"type": "text", "text": "\n".join(file_notes)})
    return content


async def get_cine_agent(model_id: str = "default"):
    """懒加载 Agent；没有 Key 时资源 REST 接口仍然可用。"""

    if model_id in _AGENTS:
        return _AGENTS[model_id]
    agent = create_agent(
        model=get_chat_model(model_id),
        tools=get_agent_tools(),
        system_prompt=SYSTEM_PROMPT,
        checkpointer=await _get_sqlite_checkpointer(),
        name="cinenest_agent",
    )
    _AGENTS[model_id] = agent
    return agent


async def invoke_agent(
    message: str,
    thread_id: str,
    *,
    model: str = "default",
    attachments: list[AgentInputAttachment] | None = None,
) -> AgentInvokeResponse:
    try:
        agent = await get_cine_agent(model)
        result = await agent.ainvoke(
            {"messages": [{"role": "user", "content": _message_payload(message, attachments)}]},
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
        model=model,
        answer=_message_text(messages[-1]),
        tool_calls=_collect_tool_calls(messages),
        attachments=_collect_attachments(messages),
    )


async def stream_agent(
    message: str,
    thread_id: str,
    *,
    model: str = "default",
    attachments: list[AgentInputAttachment] | None = None,
) -> AsyncIterator[AgentStreamEvent]:
    """把 LangChain 更新转换为稳定的 WebSocket 事件。"""

    yield AgentStreamEvent(type="started", thread_id=thread_id, data={"model": model})
    try:
        agent = await get_cine_agent(model)
        async for update in agent.astream(
            {"messages": [{"role": "user", "content": _message_payload(message, attachments)}]},
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
