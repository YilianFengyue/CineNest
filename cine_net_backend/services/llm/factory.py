"""创建模型无关的 ChatOpenAI 客户端。"""
from __future__ import annotations

from functools import lru_cache

from langchain_openai import ChatOpenAI

from config import settings
from .models import ChatModelInfo


def _model_name(model_id: str = "default") -> str:
    model_id = (model_id or "default").strip()
    aliases = {
        "default": settings.llm_model,
        "fast": settings.llm_model_fast or settings.llm_model,
        "deep": settings.llm_model_deep or settings.llm_model,
    }
    return aliases.get(model_id, settings.llm_model)


def list_chat_models() -> list[ChatModelInfo]:
    """返回前端模型选择可展示的模型列表。"""

    raw = [
        ("default", "默认模型", settings.llm_model, True),
        ("fast", "快速模型", settings.llm_model_fast or settings.llm_model, False),
        ("deep", "深度模型", settings.llm_model_deep or settings.llm_model, True),
    ]
    seen: set[str] = set()
    models: list[ChatModelInfo] = []
    for model_id, label, model_name, supports_images in raw:
        if model_id in seen:
            continue
        seen.add(model_id)
        models.append(
            ChatModelInfo(
                id=model_id,
                label=label,
                model=model_name,
                configured=bool(settings.llm_api_key.strip() and model_name.strip()),
                supports_images=supports_images,
            )
        )
    return models


def is_llm_configured(model_id: str = "default") -> bool:
    """是否已经填写 OpenAI 兼容聚合站配置。"""

    return bool(settings.llm_api_key.strip() and _model_name(model_id).strip())


@lru_cache(maxsize=8)
def get_chat_model(model_id: str = "default") -> ChatOpenAI:
    """懒加载模型。无 Key 时资源接口仍可独立运行。"""

    model_name = _model_name(model_id)
    if not is_llm_configured(model_id):
        raise RuntimeError("LLM 尚未配置：请在 .env 填写 LLM_API_KEY、LLM_BASE_URL、LLM_MODEL")
    return ChatOpenAI(
        api_key=settings.llm_api_key,
        base_url=settings.llm_base_url.rstrip("/"),
        model=model_name,
        temperature=settings.llm_temperature,
        timeout=settings.llm_timeout_seconds,
        max_retries=settings.llm_max_retries,
        stream_usage=True,
    )
