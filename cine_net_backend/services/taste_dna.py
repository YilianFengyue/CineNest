from __future__ import annotations

import asyncio
import hashlib
import json
import logging
from collections import Counter

from db.database import (
    get_collections,
    get_taste_avatar,
    get_user_preference,
    get_watch_history,
    save_taste_avatar,
)
from models.schemas import TasteAvatarResponse, TasteDNA, TasteScore
from services.images.service import generate_image, is_image_enabled


logger = logging.getLogger("cinenest.taste_dna")
_avatar_tasks: dict[str, asyncio.Task] = {}


GENRE_ALIASES = {
    "Action": "动作",
    "Adventure": "冒险",
    "Animation": "动画",
    "Comedy": "喜剧",
    "Crime": "犯罪",
    "Drama": "剧情",
    "Family": "家庭",
    "Fantasy": "奇幻",
    "History": "历史",
    "Horror": "恐怖",
    "Mystery": "悬疑",
    "Romance": "爱情",
    "Science Fiction": "科幻",
    "Sci-Fi": "科幻",
    "Thriller": "惊悚",
    "War": "战争",
}

MOOD_BY_GENRE = {
    "动作": "燃爽",
    "冒险": "探索",
    "动画": "治愈",
    "喜剧": "轻松",
    "犯罪": "黑色",
    "剧情": "沉浸",
    "家庭": "温暖",
    "奇幻": "想象力",
    "历史": "厚重",
    "恐怖": "刺激",
    "悬疑": "烧脑",
    "爱情": "浪漫",
    "科幻": "脑洞",
    "惊悚": "紧张",
    "战争": "史诗",
}


def normalize_genre(value: str) -> str:
    text = value.strip()
    return GENRE_ALIASES.get(text, text)


def build_taste_dna() -> TasteDNA:
    pref = get_user_preference()
    history = get_watch_history()
    collections = get_collections()

    scores: Counter[str] = Counter()
    liked = [normalize_genre(item) for item in pref.liked_genres if item.strip()]
    disliked = [normalize_genre(item) for item in pref.disliked_genres if item.strip()]

    for genre in liked:
        scores[genre] += 5
    for item in history[:20]:
        for genre in _infer_genres_from_title(item.title):
            scores[genre] += 1
    for item in collections[:20]:
        for genre in _infer_genres_from_title(item.title):
            scores[genre] += 2
    for genre in disliked:
        scores[genre] -= 3

    top_items = [
        TasteScore(name=name, score=max(0.0, float(score)))
        for name, score in scores.most_common()
        if score > 0
    ][:8]

    mood_tags = []
    for item in top_items:
        mood = MOOD_BY_GENRE.get(item.name)
        if mood and mood not in mood_tags:
            mood_tags.append(mood)
    if not mood_tags and pref.free_text:
        mood_tags.append("自定义偏好")

    evidence_count = len(liked) + len(history) + len(collections)
    confidence = min(0.95, 0.2 + evidence_count * 0.08)
    if not top_items:
        summary = "暂时还没有足够的观影数据。先在 Like 里选择几个喜欢的类型，再点开或收藏几部电影，画像会更准。"
        confidence = 0.15
    else:
        names = "、".join(item.name for item in top_items[:3])
        summary = f"你的观影口味更偏向 {names}，适合从这些类型里优先挑片。"
        if disliked:
            summary += f" 已尽量避开你不喜欢的 {'、'.join(disliked[:3])}。"

    payload = {
        "liked": liked,
        "disliked": disliked,
        "history": [item.title for item in history[:20]],
        "collections": [item.title for item in collections[:20]],
        "free_text": pref.free_text or "",
    }
    signature = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    ).hexdigest()
    cached = get_taste_avatar(signature)

    return TasteDNA(
        top_genres=top_items,
        avoid_genres=disliked,
        mood_tags=mood_tags[:6],
        era_tags=_build_era_tags(history),
        summary=summary,
        confidence=round(confidence, 2),
        avatar_url=cached["avatar_url"] if cached else None,
        signature=signature,
    )


def _infer_genres_from_title(title: str) -> list[str]:
    text = title.lower()
    pairs = [
        ("toy story", "动画"),
        ("spider", "动作"),
        ("batman", "动作"),
        ("godfather", "犯罪"),
        ("shawshank", "剧情"),
        ("fight club", "剧情"),
        ("forrest", "剧情"),
        ("pulp", "犯罪"),
        ("西游记", "奇幻"),
        ("喜剧", "喜剧"),
        ("动画", "动画"),
        ("恐怖", "恐怖"),
        ("爱情", "爱情"),
        ("科幻", "科幻"),
        ("悬疑", "悬疑"),
    ]
    return [genre for key, genre in pairs if key in text]


def _build_era_tags(history) -> list[str]:
    if len(history) >= 5:
        return ["近期观影活跃", "偏好正在成型"]
    if history:
        return ["少量历史样本"]
    return ["等待更多观影记录"]


def build_avatar_prompt(dna: TasteDNA) -> str:
    genres = ", ".join(item.name for item in dna.top_genres[:4]) or "movie discovery"
    moods = ", ".join(dna.mood_tags[:4]) or "curious and cozy"
    return (
        "Cute chibi avatar of a movie fan, square app profile illustration. "
        f"Personality taste: {genres}. Mood keywords: {moods}. "
        "Cinematic props, soft lighting, expressive face, colorful but clean, "
        "no text, no watermark, no logo."
    )


async def generate_taste_avatar(force: bool = False) -> TasteAvatarResponse:
    dna = build_taste_dna()
    prompt = build_avatar_prompt(dna)
    cached = get_taste_avatar(dna.signature)
    if cached and not force:
        return TasteAvatarResponse(
            avatar_url=cached["avatar_url"],
            prompt=cached["prompt"],
            cached=True,
            signature=dna.signature,
        )
    if not is_image_enabled():
        raise RuntimeError("AI image service is not configured. Please set IMAGE_API_KEY or LLM_API_KEY.")

    if cached and force:
        _start_background_avatar_generation(dna.signature, prompt)
        return TasteAvatarResponse(
            avatar_url=cached["avatar_url"],
            prompt=cached["prompt"],
            cached=True,
            signature=dna.signature,
            warning="A new AI avatar is being generated in the background. Keep this page open or tap refresh in a moment.",
        )

    asset = await generate_image(
        prompt,
        size="1024x1024",
        timeout_seconds=180,
        attempts=2,
    )
    if asset is None:
        if cached:
            return TasteAvatarResponse(
                avatar_url=cached["avatar_url"],
                prompt=cached["prompt"],
                cached=True,
                signature=dna.signature,
                warning="New AI image generation failed, so the previous AI avatar is kept.",
            )
        raise RuntimeError("AI image generation failed. Please check API key, quota, and network.")
    avatar_url = f"/api/assets/{asset.id}"
    save_taste_avatar(dna.signature, avatar_url, prompt)
    return TasteAvatarResponse(
        avatar_url=avatar_url,
        prompt=prompt,
        cached=False,
        signature=dna.signature,
    )


def _start_background_avatar_generation(signature: str, prompt: str) -> None:
    task = _avatar_tasks.get(signature)
    if task is not None and not task.done():
        return
    _avatar_tasks[signature] = asyncio.create_task(
        _generate_avatar_in_background(signature, prompt)
    )


async def _generate_avatar_in_background(signature: str, prompt: str) -> None:
    try:
        asset = await generate_image(
            prompt,
            size="1024x1024",
            timeout_seconds=240,
            attempts=2,
        )
        if asset is None:
            logger.warning("Taste DNA background avatar generation returned no asset.")
            return
        save_taste_avatar(signature, f"/api/assets/{asset.id}", prompt)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Taste DNA background avatar generation failed: %s", exc)
    finally:
        finished = _avatar_tasks.get(signature)
        if finished is not None and finished.done():
            _avatar_tasks.pop(signature, None)
