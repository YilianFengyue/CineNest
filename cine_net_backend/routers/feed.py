"""推荐帖子流。Step 1 直接基于真实 MacCMS 结果生成 MicroDesign 帖子。"""
from fastapi import APIRouter, Query

from models import Feedback, UserPreference
from services.microdesign import compose_recommendation_posts
from services.microdesign.models import MicroDesignPost
from services.recommendation import get_recommendation_service
from services.recommendation.models import RecommendationFeed
from services.resources import get_resource_aggregator

router = APIRouter(prefix="/api", tags=["feed"])


@router.get("/feed", response_model=list[MicroDesignPost])
async def get_feed(
    keyword: str = Query("星际穿越", min_length=1, max_length=100),
    limit: int = Query(10, ge=1, le=20),
) -> list[MicroDesignPost]:
    """按关键词生成可直接渲染的 MicroDesign 帖子。"""

    response = await get_resource_aggregator().search(keyword)
    return compose_recommendation_posts(response, limit=limit)


@router.get("/feed/recommend", response_model=RecommendationFeed)
async def recommend_feed(
    query: str = Query("", max_length=100),
    media_kind: str = Query("movie", pattern="^(movie|tv)$"),
    limit: int = Query(5, ge=1, le=10),
    refresh: bool = False,
) -> RecommendationFeed:
    """先查豆瓣/TMDB 资料，再确认播放资源，输出完整推荐帖子。"""

    return await get_recommendation_service().recommend(query=query, media_kind=media_kind, limit=limit, refresh=refresh)


@router.post("/preferences")
async def set_preferences(pref: UserPreference):
    """保存用户偏好。TODO(B): 后续落库 SQLite，作为推荐输入。"""

    return {"ok": True, "saved": pref.model_dump()}


@router.post("/feedback")
async def post_feedback(fb: Feedback):
    """喜欢/不感兴趣反馈。TODO(B): 后续影响推荐。"""

    return {"ok": True}
