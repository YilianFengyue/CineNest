"""LangChain v1 Agent Core。"""
from __future__ import annotations

from functools import lru_cache
from typing import Any, AsyncIterator

from langchain.agents import create_agent
from langchain_core.messages import AIMessage, BaseMessage, ToolMessage
from langgraph.checkpoint.memory import InMemorySaver

from services.llm import get_chat_model
from services.tools import get_agent_tools

from .schemas import AgentInvokeResponse, AgentStreamEvent

SYSTEM_PROMPT = """\
你是 CineNest 的影视资源策展 Agent。
你的回答必须基于工具返回的真实数据，不得编造影片资源、资源站、播放 URL 或剧集。
当用户找片、询问可播放资源、请求推荐帖子或动态海报时，优先调用合适的工具。
如果工具没有返回结果，明确告诉用户暂未检索到，不要用常识补造播放线路。
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
    result = await get_cine_agent().ainvoke(
        {"messages": [{"role": "user", "content": message}]},
        config=_config(thread_id),
    )
    messages = result["messages"]
    return AgentInvokeResponse(
        thread_id=thread_id,
        answer=_message_text(messages[-1]),
        tool_calls=_collect_tool_calls(messages),
    )


async def stream_agent(message: str, thread_id: str) -> AsyncIterator[AgentStreamEvent]:
    """把 LangChain 更新转换为稳定的 WebSocket 事件。"""

    yield AgentStreamEvent(type="started", thread_id=thread_id)
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
                elif isinstance(current, AIMessage):
                    for call in current.tool_calls:
                        yield AgentStreamEvent(type="tool_started", thread_id=thread_id, data=call)
                    text = _message_text(current)
                    if text:
                        yield AgentStreamEvent(type="delta", thread_id=thread_id, content=text)
    yield AgentStreamEvent(type="done", thread_id=thread_id)
