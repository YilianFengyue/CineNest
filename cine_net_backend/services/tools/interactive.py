"""Agent 交互卡片工具。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.microdesign import compose_movie_carousel, compose_review_quote_card, compose_source_trace_card
from services.microdesign.models import InteractiveCardsPayload
from services.recommendation import get_recommendation_service


def _json(payload) -> str:
    return json.dumps(payload, ensure_ascii=False)


@tool
async def build_interactive_answer(query: str, media_kind: str = "movie", limit: int = 3) -> str:
    """为聊天回答生成交互卡片：可播放电影卡、电影轮播、评价卡、来源追踪卡。"""

    feed = await get_recommendation_service().recommend(
        query=query,
        media_kind=media_kind,
        limit=max(1, min(limit, 6)),
        refresh=True,
    )
    cards = []
    for post in feed.posts[:limit]:
        cards.extend(post.blocks)
        cards.append(compose_review_quote_card(post))
    if feed.posts:
        cards.append(compose_movie_carousel(feed.posts))
    cards.append(
        compose_source_trace_card(
            query=query,
            catalog_ok=sum(1 for trace in feed.catalog_traces if trace.ok),
            catalog_failed=sum(1 for trace in feed.catalog_traces if not trace.ok),
            resource_count=len(feed.posts),
            resource_hint=f"返回 {len(feed.posts)} 个真实可播放候选",
        )
    )
    payload = InteractiveCardsPayload(cards=cards, actions=[action for post in feed.posts for action in post.actions])
    return _json(payload.model_dump())
