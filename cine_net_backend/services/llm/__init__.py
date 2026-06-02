"""OpenAI 兼容模型工厂。"""

from .factory import get_chat_model, is_llm_configured

__all__ = ["get_chat_model", "is_llm_configured"]
