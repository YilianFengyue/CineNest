"""辩论式推荐 Agent Tool。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.debate import DebateRecommendationRequest, build_debate_recommendation


@tool
async def debate_movie_recommendation(
    movie: str,
    overview: str = "",
    year: str = "",
    source_name: str = "",
    playable: bool = True,
    rating: str = "",
    user_id: str = "default",
) -> str:
    """模拟影视推荐委员会，从口味、资源、口碑、反方审查四个视角评价一部电影。"""

    envelope = await build_debate_recommendation(
        DebateRecommendationRequest(
            user_id=user_id,
            movie=movie,
            year=year or None,
            overview=overview,
            source_name=source_name,
            playable=playable,
            rating=rating or None,
        )
    )
    return json.dumps(envelope.model_dump(), ensure_ascii=False)
