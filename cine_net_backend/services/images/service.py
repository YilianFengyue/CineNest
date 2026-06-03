"""AI 图片生成（OpenAI Images 兼容）。

把生成的图片落地为本地 asset，返回可经 `/api/assets/{id}` 访问的相对 URL。
失败一律返回 None，由调用方回退到 TMDB/豆瓣海报，绝不阻塞主流程。
"""
from __future__ import annotations

import base64
import logging

import httpx

from config import settings
from services.assets import save_bytes
from services.assets.models import AssetRecord

logger = logging.getLogger("cinenest.images")


def _api_key() -> str:
    return (settings.image_api_key or settings.llm_api_key).strip()


def _base_url() -> str:
    return (settings.image_base_url or settings.llm_base_url).rstrip("/")


def is_image_enabled() -> bool:
    """是否具备生成条件（开关打开且有可用 Key）。"""

    return settings.image_enabled and bool(_api_key())


def movie_image_prompt(
    title: str,
    genres: list[str],
    overview: str,
    *,
    kind: str = "poster",
) -> str:
    """根据影片资料拼出影视级生图提示词（英文，模型更稳）。"""

    genre = ", ".join(g for g in genres[:3] if g) or "drama"
    mood = (overview or "").strip().replace("\n", " ")[:300]
    return (
        f'Cinematic {kind} key art for the movie "{title}". '
        f"Genre: {genre}. Atmosphere inspired by: {mood}. "
        "Dramatic lighting, rich film color grading, highly detailed, "
        "epic composition, no text, no captions, no watermark, no logo."
    )


async def generate_image(
    prompt: str,
    *,
    size: str = "1024x1024",
    model: str | None = None,
) -> AssetRecord | None:
    """生成一张图片并存为 asset。失败返回 None。"""

    if not is_image_enabled():
        return None
    payload = {
        "prompt": prompt[:1000],
        "model": model or settings.image_model,
        "n": 1,
        "size": size,
    }
    headers = {"Authorization": f"Bearer {_api_key()}"}
    try:
        async with httpx.AsyncClient(timeout=settings.image_timeout_seconds) as client:
            resp = await client.post(
                f"{_base_url()}/images/generations",
                headers=headers,
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            items = data.get("data") or []
            if not items:
                logger.warning("图片生成返回空 data")
                return None
            first = items[0]
            content: bytes | None = None
            if first.get("b64_json"):
                content = base64.b64decode(first["b64_json"])
            elif first.get("url"):
                img = await client.get(first["url"])
                img.raise_for_status()
                content = img.content
            if not content:
                return None
            return save_bytes(content, mime="image/png", filename="ai_poster.png")
    except Exception as exc:  # noqa: BLE001 — 生图失败必须降级，不能影响主流程
        logger.warning("图片生成失败，已降级: %s", exc)
        return None
