"""创建模型无关的 ChatOpenAI 客户端。"""
from __future__ import annotations

from functools import lru_cache

from langchain_openai import ChatOpenAI

from config import settings


def is_llm_configured() -> bool:
    """是否已经填写 OpenAI 兼容聚合站配置。"""

    return bool(settings.llm_api_key.strip() and settings.llm_model.strip())


@lru_cache(maxsize=1)
def get_chat_model() -> ChatOpenAI:
    """懒加载模型。无 Key 时资源接口仍可独立运行。"""

    if not is_llm_configured():
        raise RuntimeError("LLM 尚未配置：请在 .env 填写 LLM_API_KEY、LLM_BASE_URL、LLM_MODEL")
    return ChatOpenAI(
        api_key=settings.llm_api_key,
        base_url=settings.llm_base_url.rstrip("/"),
        model=settings.llm_model,
        temperature=settings.llm_temperature,
        timeout=settings.llm_timeout_seconds,
        stream_usage=True,
    )
