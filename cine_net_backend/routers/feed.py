"""成员 B 的 API 路由：推荐帖子流 / 详情 / 偏好 / 反馈。

当前为 mock 实现，保证前端 Day1 可联调；真实逻辑接入 services/agent + services/tmdb。
"""
from fastapi import APIRouter

from models import Post, Movie, UserPreference, Feedback

router = APIRouter(prefix="/api", tags=["feed (成员B)"])


def _mock_movie(i: int) -> Movie:
    return Movie(
        id=550 + i,
        title=f"示例电影 {i}",
        original_title=f"Sample Movie {i}",
        year=1999 + i,
        genres=["剧情", "科幻"],
        rating=8.0 + i * 0.1,
        overview="这是一段占位简介，真实数据接入 TMDB 后替换。",
        poster_url="https://image.tmdb.org/t/p/w500/placeholder.jpg",
    )


@router.get("/feed", response_model=list[Post])
async def get_feed(refresh: bool = False):
    """首页帖子流。TODO(B): 接入 Agent 推荐链。"""
    return [
        Post(
            movie=_mock_movie(i),
            recommend_reason="你喜欢烧脑反转，这部不会让你失望",
            has_video_source=True,
            has_bilibili=True,
        )
        for i in range(10)
    ]


@router.get("/movie/{movie_id}", response_model=Movie)
async def get_movie(movie_id: int):
    """电影详情。TODO(B): 接入 TMDB 详情。"""
    return _mock_movie(movie_id % 10)


@router.post("/preferences")
async def set_preferences(pref: UserPreference):
    """保存用户偏好。TODO(B): 落库 SQLite，作为推荐输入。"""
    return {"ok": True, "saved": pref.model_dump()}


@router.post("/feedback")
async def post_feedback(fb: Feedback):
    """喜欢/不感兴趣反馈。TODO(B): 影响后续推荐。"""
    return {"ok": True}
