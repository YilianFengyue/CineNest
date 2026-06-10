"""创建模型无关的 ChatOpenAI 客户端。"""
from __future__ import annotations

from functools import lru_cache

from langchain_openai import ChatOpenAI

from config import settings
from .models import ChatModelInfo

GEMINI_MODEL = "gemini-3.5-flash"
GPT_MODEL = "gpt-5.5"
KIMI_MODEL = "Kimi-K2.6"


def _model_name(model_id: str = "default") -> str:
    model_id = (model_id or "default").strip()
    aliases = {
        "default": settings.llm_model or GEMINI_MODEL,
        "fast": settings.llm_model_fast or GPT_MODEL,
        "deep": settings.llm_model_deep or KIMI_MODEL,
    }
    return aliases.get(model_id, aliases["default"])


def _looks_image_capable(model_name: str) -> bool:
    lowered = (model_name or "").lower()
    return any(
        hint in lowered
        for hint in (
            "gemini",
            "gpt-4o",
            "gpt-5",
            "vision",
            "qwen-vl",
            "qwen2-vl",
            "qwen2.5-vl",
            "claude-3",
            "claude-4",
        )
    )


def list_chat_models() -> list[ChatModelInfo]:
    """返回前端模型选择可展示的模型列表。"""

    default_model = _model_name("default")
    gpt_model = _model_name("fast")
    kimi_model = _model_name("deep")
    default_supports_images = True
    raw = [
        ("default", "Gemini", default_model, default_supports_images),
        (
            "fast",
            "GPT-5.5",
            gpt_model,
            (gpt_model == default_model and default_supports_images) or _looks_image_capable(gpt_model),
        ),
        ("deep", "Kimi-K2.6", kimi_model, kimi_model == default_model or _looks_image_capable(kimi_model)),
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


def model_supports_images(model_id: str = "default") -> bool:
    """当前模型别名是否允许接收 image_url 多模态内容。"""

    model_id = (model_id or "default").strip()
    for item in list_chat_models():
        if item.id == model_id:
            return item.supports_images
    return False


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
