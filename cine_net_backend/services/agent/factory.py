"""LangChain v1 Agent Core。"""
from __future__ import annotations

import json
import asyncio
import re
from typing import Any, AsyncIterator

from langchain.agents import create_agent
from langchain_core.messages import AIMessage, BaseMessage, ToolMessage
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from config import settings
from services.assets import AgentInputAttachment, asset_data_url, get_asset
from services.llm import get_chat_model, model_supports_images
from services.news import create_news_task, run_news_task
from services.tools import get_agent_tools
from services.tools.interactive import build_interactive_answer

from .schemas import AgentAttachment, AgentInvokeResponse, AgentStreamEvent

_ATTACHMENT_TYPES = {
    "build_recommendation_feed": "recommendation_feed",
    "build_catalog_microdesign_poster": "microdesign_poster",
    "build_interactive_answer": "interactive_cards",
    "collect_movie_news": "news_feed",
    "generate_movie_news": "news_task",
}

_NEWS_GENERATE_RE = re.compile(r"^(?:生成影视资讯|生成影讯|AI影讯|ai影讯)[:：]\s*(.+)$")


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
当用户要求“为某部电影生成资讯/特辑/海报资讯”时，调用 generate_movie_news 提交后台任务；任务完成后会持久化到资讯列表。
当用户上传图片时，先观察图片本身：描述画面、人物、文字、海报/截图/剧照线索；如果用户要识片、找片、推荐或播放，再结合可见线索调用 Catalog/Resource 工具核验。
图片内容可以作为用户提供的视觉证据，但影视事实、评分、播放源和播放 URL 仍必须通过工具确认。
做电影推荐、找相似电影、找高分片、找可播放资源时，必须调用 build_interactive_answer 返回富媒体卡片；不要只给纯文本片单。
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


def _news_generation_query(message: str) -> str:
    match = _NEWS_GENERATE_RE.match(message.strip())
    return match.group(1).strip() if match else ""


def _submit_news_generation_task(query: str) -> AgentAttachment:
    task = create_news_task(query)
    asyncio.create_task(run_news_task(task.id))
    payload = task.model_dump()
    return AgentAttachment(
        type="news_task",
        schema_version="microdesign.v1.1",
        payload=payload,
    )


def _looks_resource_or_recommendation_request(message: str) -> bool:
    markers = ("推荐", "找部", "找一部", "高分", "可播放", "播放", "资源", "片源", "像《")
    return any(marker in message for marker in markers)


async def _fallback_interactive_attachment(message: str) -> AgentAttachment | None:
    try:
        payload = json.loads(await build_interactive_answer.ainvoke({"query": message, "limit": 3}))
    except Exception:
        return None
    if not isinstance(payload, dict) or not payload.get("cards"):
        return None
    return AgentAttachment(
        type="interactive_cards",
        schema_version=str(payload.get("schema_version") or "microdesign.v1.1"),
        payload=payload,
    )


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


def _message_payload(
    message: str,
    attachments: list[AgentInputAttachment] | None = None,
    *,
    model: str = "default",
):
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
        if record.kind == "image" and model_supports_images(model):
            content.append({"type": "image_url", "image_url": {"url": asset_data_url(record)}})
        elif record.kind == "image":
            file_notes.append(
                f"用户上传了图片 {record.filename}，但当前模型别名 {model} 不支持视觉输入。"
                "请提示用户切换到支持图片的模型后再分析图片。"
            )
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
    news_query = _news_generation_query(message)
    if news_query:
        attachment = _submit_news_generation_task(news_query)
        return AgentInvokeResponse(
            thread_id=thread_id,
            model=model,
            answer=f"已提交《{news_query}》的影视资讯生成任务，完成后会出现在资讯页。",
            tool_calls=[{"name": "generate_movie_news", "args": {"query": news_query}}],
            attachments=[attachment],
        )
    try:
        agent = await get_cine_agent(model)
        result = await agent.ainvoke(
            {"messages": [{"role": "user", "content": _message_payload(message, attachments, model=model)}]},
            config=_config(thread_id),
        )
    except Exception as exc:
        friendly = _friendly_upstream_error(exc)
        if friendly is None:
            raise
        raise friendly from exc
    messages = result["messages"]
    tool_calls = _collect_tool_calls(messages)
    attachments = _collect_attachments(messages)
    if not attachments and (
        _looks_resource_or_recommendation_request(message)
        or any(call.get("name") == "search_playable_resources" for call in tool_calls)
    ):
        fallback = await _fallback_interactive_attachment(message)
        if fallback is not None:
            attachments.append(fallback)
    return AgentInvokeResponse(
        thread_id=thread_id,
        model=model,
        answer=_message_text(messages[-1]),
        tool_calls=tool_calls,
        attachments=attachments,
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
    news_query = _news_generation_query(message)
    if news_query:
        call = {"name": "generate_movie_news", "args": {"query": news_query}}
        yield AgentStreamEvent(type="tool_started", thread_id=thread_id, data=call)
        try:
            attachment = _submit_news_generation_task(news_query)
        except Exception as exc:  # noqa: BLE001
            yield AgentStreamEvent(type="error", thread_id=thread_id, content=f"资讯任务创建失败: {exc}")
            return
        yield AgentStreamEvent(
            type="tool_finished",
            thread_id=thread_id,
            data={"tool_name": "generate_movie_news", "content": json.dumps(attachment.payload, ensure_ascii=False)},
        )
        yield AgentStreamEvent(type="attachment", thread_id=thread_id, data=attachment.model_dump())
        yield AgentStreamEvent(
            type="delta",
            thread_id=thread_id,
            content=f"已提交《{news_query}》的影视资讯生成任务。你可以在资讯页查看后台进度。",
        )
        yield AgentStreamEvent(type="done", thread_id=thread_id)
        return
    try:
        agent = await get_cine_agent(model)
        used_tools: list[str] = []
        attachment_count = 0
        async for update in agent.astream(
            {"messages": [{"role": "user", "content": _message_payload(message, attachments, model=model)}]},
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
                            attachment_count += 1
                            yield AgentStreamEvent(
                                type="attachment",
                                thread_id=thread_id,
                                data=attachment.model_dump(),
                            )
                    elif isinstance(current, AIMessage):
                        for call in current.tool_calls:
                            used_tools.append(str(call.get("name") or ""))
                            yield AgentStreamEvent(type="tool_started", thread_id=thread_id, data=call)
                        text = _message_text(current)
                        if text:
                            yield AgentStreamEvent(type="delta", thread_id=thread_id, content=text)
        if attachment_count == 0 and (
            _looks_resource_or_recommendation_request(message)
            or "search_playable_resources" in used_tools
        ):
            fallback = await _fallback_interactive_attachment(message)
            if fallback is not None:
                yield AgentStreamEvent(
                    type="attachment",
                    thread_id=thread_id,
                    data=fallback.model_dump(),
                )
    except Exception as exc:
        friendly = _friendly_upstream_error(exc)
        if friendly is None:
            raise
        raise friendly from exc
    yield AgentStreamEvent(type="done", thread_id=thread_id)
