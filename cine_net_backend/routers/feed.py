"""推荐、探索、偏好、历史与收藏 API。"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from config import settings
from db.database import (
    add_watch_history,
    get_collections,
    get_user_preference,
    get_watch_history,
    get_watch_history_titles,
    is_movie_collected,
    save_user_preference,
    toggle_collection,
)
from models.schemas import (
    CollectionItem,
    CollectionToggleRequest,
    Feedback,
    Movie,
    Post,
    ScenarioResponse,
    UserPreference,
    WatchHistoryItem,
    WatchHistoryRequest,
)
from services.agent.service import movie_agent_service
from services.microdesign import compose_recommendation_posts
from services.microdesign.models import MicroDesignPost
from services.recommendation import get_recommendation_service
from services.recommendation.models import RecommendationFeed
from services.resources import get_resource_aggregator
from services.tmdb import tmdb_service

router = APIRouter(prefix="/api", tags=["feed"])


FALLBACK_MOVIES = [
    Movie(
        id=278,
        title="The Shawshank Redemption",
        original_title="The Shawshank Redemption",
        year=1994,
        genres=["Drama", "Crime"],
        rating=9.3,
        overview="A banker sentenced to life in prison holds on to hope and friendship.",
        directors=["Frank Darabont"],
        cast=["Tim Robbins", "Morgan Freeman"],
    ),
    Movie(
        id=238,
        title="The Godfather",
        original_title="The Godfather",
        year=1972,
        genres=["Crime", "Drama"],
        rating=9.2,
        overview="The aging patriarch of a crime dynasty transfers control to his reluctant son.",
        directors=["Francis Ford Coppola"],
        cast=["Marlon Brando", "Al Pacino"],
    ),
    Movie(
        id=550,
        title="Fight Club",
        original_title="Fight Club",
        year=1999,
        genres=["Drama"],
        rating=8.8,
        overview="An office worker and a soap maker form an underground fight club.",
        directors=["David Fincher"],
        cast=["Edward Norton", "Brad Pitt"],
    ),
    Movie(
        id=680,
        title="Pulp Fiction",
        original_title="Pulp Fiction",
        year=1994,
        genres=["Crime", "Drama"],
        rating=8.9,
        overview="Interwoven stories of crime, loyalty, and chaos in Los Angeles.",
        directors=["Quentin Tarantino"],
        cast=["John Travolta", "Uma Thurman", "Samuel L. Jackson"],
    ),
    Movie(
        id=155,
        title="The Dark Knight",
        original_title="The Dark Knight",
        year=2008,
        genres=["Action", "Crime", "Drama"],
        rating=9.0,
        overview="Batman faces the Joker, who wants to plunge Gotham into chaos.",
        directors=["Christopher Nolan"],
        cast=["Christian Bale", "Heath Ledger"],
    ),
    Movie(
        id=13,
        title="Forrest Gump",
        original_title="Forrest Gump",
        year=1994,
        genres=["Drama", "Romance"],
        rating=8.8,
        overview="A kind-hearted man witnesses defining moments in American history.",
        directors=["Robert Zemeckis"],
        cast=["Tom Hanks", "Robin Wright"],
    ),
    Movie(
        id=27205,
        title="Inception",
        original_title="Inception",
        year=2010,
        genres=["Action", "Science Fiction"],
        rating=8.8,
        overview="A thief who steals secrets through dreams is offered a chance to erase his past.",
        directors=["Christopher Nolan"],
        cast=["Leonardo DiCaprio", "Joseph Gordon-Levitt"],
    ),
    Movie(
        id=603,
        title="The Matrix",
        original_title="The Matrix",
        year=1999,
        genres=["Action", "Science Fiction"],
        rating=8.7,
        overview="A hacker discovers that reality is a simulated world controlled by machines.",
        directors=["Lana Wachowski", "Lilly Wachowski"],
        cast=["Keanu Reeves", "Laurence Fishburne"],
    ),
    Movie(
        id=120,
        title="The Lord of the Rings: The Fellowship of the Ring",
        original_title="The Lord of the Rings: The Fellowship of the Ring",
        year=2001,
        genres=["Adventure", "Fantasy"],
        rating=8.8,
        overview="A young hobbit begins a dangerous journey to destroy a powerful ring.",
        directors=["Peter Jackson"],
        cast=["Elijah Wood", "Ian McKellen"],
    ),
    Movie(
        id=1891,
        title="The Empire Strikes Back",
        original_title="The Empire Strikes Back",
        year=1980,
        genres=["Adventure", "Science Fiction"],
        rating=8.7,
        overview="The Rebels are pursued by the Empire while Luke trains with Yoda.",
        directors=["Irvin Kershner"],
        cast=["Mark Hamill", "Harrison Ford"],
    ),
    Movie(
        id=129,
        title="Spirited Away",
        original_title="Spirited Away",
        year=2001,
        genres=["Animation", "Fantasy"],
        rating=8.6,
        overview="A girl enters a mysterious spirit world and must save her parents.",
        directors=["Hayao Miyazaki"],
        cast=["Rumi Hiiragi", "Miyu Irino"],
    ),
    Movie(
        id=496243,
        title="Parasite",
        original_title="Parasite",
        year=2019,
        genres=["Drama", "Thriller"],
        rating=8.5,
        overview="Two families from different social classes become entangled in a darkly comic story.",
        directors=["Bong Joon-ho"],
        cast=["Song Kang-ho", "Choi Woo-shik"],
    ),
]


TMDB_GENRE_IDS = {
    "动作": 28,
    "冒险": 12,
    "动画": 16,
    "喜剧": 35,
    "犯罪": 80,
    "纪录": 99,
    "纪录片": 99,
    "剧情": 18,
    "家庭": 10751,
    "奇幻": 14,
    "历史": 36,
    "恐怖": 27,
    "音乐": 10402,
    "悬疑": 9648,
    "爱情": 10749,
    "科幻": 878,
    "电视电影": 10770,
    "惊悚": 53,
    "战争": 10752,
    "西部": 37,
}


def _fallback_movie(movie_id: int) -> Movie:
    for movie in FALLBACK_MOVIES:
        if movie.id == movie_id:
            return movie
    return FALLBACK_MOVIES[0].model_copy(update={"id": movie_id})


def _has_preferences(pref: UserPreference) -> bool:
    return bool(pref.liked_genres or pref.disliked_genres or (pref.free_text or "").strip())


def _fallback_posts() -> list[Post]:
    return [
        Post(
            movie=movie,
            recommend_reason="Local fallback recommendation for offline testing.",
            has_video_source=True,
            has_bilibili=True,
        )
        for movie in FALLBACK_MOVIES
    ]


def _genre_ids(genres: list[str]) -> list[int]:
    ids = []
    for genre in genres:
        genre_id = TMDB_GENRE_IDS.get(genre.strip())
        if genre_id and genre_id not in ids:
            ids.append(genre_id)
    return ids


def _safe_add_watch_history(movie_id: int, title: str) -> None:
    try:
        add_watch_history(movie_id=movie_id, title=title)
    except Exception as exc:  # noqa: BLE001
        print(f"[history fallback] add watch history failed: {exc}", flush=True)


async def _preference_posts(pref: UserPreference) -> list[Post]:
    liked_ids = _genre_ids(pref.liked_genres)
    disliked_ids = _genre_ids(pref.disliked_genres)
    if not liked_ids or not settings.tmdb_api_key:
        return []

    movies = await tmdb_service.discover_by_genres(
        genre_ids=liked_ids,
        excluded_genre_ids=disliked_ids,
    )
    if not movies:
        return []

    liked_label = "、".join(pref.liked_genres)
    return [
        Post(
            movie=movie,
            recommend_reason=f"根据你在设置页选择的「{liked_label}」偏好，从 TMDB 类型库中为你筛选。",
            has_video_source=True,
            has_bilibili=True,
        )
        for movie in movies[:8]
    ]


@router.get("/feed", response_model=list[Post])
async def get_feed(
    refresh: bool = False,
    sort_by: str = Query("popularity", description="popularity or rating"),
    scenario: str | None = Query(None, description="场景化推荐，如'下饭电影'"),
):
    """成员 B 首页专属推荐主入口。"""

    # 如果有特定场景，直接走 Agent 语义路径
    if scenario:
        try:
            posts = await movie_agent_service.get_personalized_feed("", scenario=scenario)
            return posts or _fallback_posts()
        except Exception as exc:  # noqa: BLE001
            print(f"[Agent scenario fallback] feed failed: {exc}", flush=True)
            return _fallback_posts()

    local_pref = get_user_preference()
    history_titles = get_watch_history_titles()

    if _has_preferences(local_pref):
        try:
            posts = await _preference_posts(local_pref)
            if posts:
                return posts
        except Exception as exc:  # noqa: BLE001
            print(f"[TMDB preference fallback] discover failed: {exc}", flush=True)

    prompt = "[User preference]\n"
    if local_pref.liked_genres:
        prompt += f"- liked: {', '.join(local_pref.liked_genres)}\n"
    if local_pref.disliked_genres:
        prompt += f"- disliked: {', '.join(local_pref.disliked_genres)}\n"
    if local_pref.free_text:
        prompt += f"- notes: {local_pref.free_text}\n"
    if history_titles:
        prompt += f"- watched: {', '.join(history_titles)}\n"
    prompt += f"\nRecommend movies sorted by {sort_by}. refresh={refresh}"

    try:
        posts = await movie_agent_service.get_personalized_feed(prompt)
        return posts or _fallback_posts()
    except Exception as exc:  # noqa: BLE001
        print(f"[Agent fallback] feed failed: {exc}", flush=True)
        return _fallback_posts()


@router.get("/feed/scenario", response_model=ScenarioResponse)
async def get_scenario_feed(
    scenario: str = Query(..., min_length=1, max_length=100),
):
    """独立场景化推荐页专属接口。"""

    local_pref = get_user_preference()
    prompt = ""
    if local_pref.liked_genres:
        prompt += f"喜欢的类型: {', '.join(local_pref.liked_genres)}. "
    if local_pref.free_text:
        prompt += f"偏好描述: {local_pref.free_text}"

    try:
        return await movie_agent_service.get_scenario_recommendation(prompt, scenario)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Scenario recommendation failed: {exc}") from exc


@router.get("/feed/microdesign", response_model=list[MicroDesignPost])
async def get_microdesign_feed(
    keyword: str = Query("星际穿越", min_length=1, max_length=100),
    limit: int = Query(10, ge=1, le=20),
) -> list[MicroDesignPost]:
    """成员 C MicroDesign 关键词帖子，迁到子路径以免覆盖 B 的 /api/feed。"""

    response = await get_resource_aggregator().search(keyword)
    return compose_recommendation_posts(response, limit=limit)


@router.get("/feed/recommend", response_model=RecommendationFeed)
async def recommend_feed(
    query: str = Query("", max_length=100),
    media_kind: str = Query("movie", pattern="^(movie|tv)$"),
    limit: int = Query(5, ge=1, le=10),
    refresh: bool = False,
) -> RecommendationFeed:
    """成员 C 确定性推荐：先查豆瓣/TMDB，再确认播放资源。"""

    return await get_recommendation_service().recommend(
        query=query,
        media_kind=media_kind,
        limit=limit,
        refresh=refresh,
    )


@router.get("/movie/{movie_id}", response_model=Movie)
async def get_movie(movie_id: int):
    if not settings.tmdb_api_key:
        movie = _fallback_movie(movie_id)
        movie.is_collected = is_movie_collected(movie_id)
        _safe_add_watch_history(movie.id, movie.title)
        return movie
    try:
        movie_data = await tmdb_service.detail(movie_id)
        movie_data.is_collected = is_movie_collected(movie_id)
        _safe_add_watch_history(movie_data.id, movie_data.title)
        return movie_data
    except Exception as exc:  # noqa: BLE001
        print(f"[TMDB fallback] movie detail failed: {exc}", flush=True)
        movie = _fallback_movie(movie_id)
        movie.is_collected = is_movie_collected(movie_id)
        _safe_add_watch_history(movie.id, movie.title)
        return movie


@router.get("/discovery", response_model=list[Movie])
async def get_discovery(page: int = 1):
    if not settings.tmdb_api_key:
        return FALLBACK_MOVIES
    try:
        movies = await tmdb_service.popular(page=page)
        return movies or FALLBACK_MOVIES
    except Exception as exc:  # noqa: BLE001
        print(f"[TMDB fallback] discovery failed: {exc}", flush=True)
        return FALLBACK_MOVIES


@router.post("/preferences")
async def set_preferences(pref: UserPreference):
    try:
        save_user_preference(pref)
        return {"ok": True, "saved": pref.model_dump()}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Save preferences failed: {exc}") from exc


@router.get("/preferences", response_model=UserPreference)
async def get_preferences():
    try:
        return get_user_preference()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Get preferences failed: {exc}") from exc


@router.post("/feedback")
async def post_feedback(fb: Feedback):
    return {"ok": True, "movie_id": fb.movie_id, "liked": fb.liked}


@router.get("/history", response_model=list[WatchHistoryItem])
async def get_history():
    try:
        return get_watch_history()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Get watch history failed: {exc}") from exc


@router.post("/history/record")
async def record_history(req: WatchHistoryRequest):
    try:
        add_watch_history(movie_id=req.movie_id, title=req.title)
        return {"ok": True}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Record history failed: {exc}") from exc


@router.post("/collections/toggle")
async def toggle_movie_collection(req: CollectionToggleRequest):
    try:
        is_collected = toggle_collection(
            movie_id=req.movie_id,
            title=req.title,
            poster_url=req.poster_url,
        )
        return {"ok": True, "is_collected": is_collected}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Toggle collection failed: {exc}") from exc


@router.get("/collections", response_model=list[CollectionItem])
async def get_user_collections():
    try:
        return get_collections()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Get collections failed: {exc}") from exc
