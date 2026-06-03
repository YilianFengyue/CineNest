from fastapi import APIRouter, HTTPException, Query

from config import settings
from db.database import (
    add_watch_history,
    get_user_preference,
    get_watch_history_titles,
    save_user_preference,
)
from models.schemas import Feedback, Movie, Post, UserPreference
from services.agent.service import movie_agent_service
from services.tmdb import tmdb_service

router = APIRouter(prefix="/api", tags=["feed (member B)"])


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


def _fallback_movie(movie_id: int) -> Movie:
    for movie in FALLBACK_MOVIES:
        if movie.id == movie_id:
            return movie
    return FALLBACK_MOVIES[0].model_copy(update={"id": movie_id})


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


@router.get("/movie/{movie_id}", response_model=Movie)
async def get_movie(movie_id: int):
    if not settings.tmdb_api_key:
        return _fallback_movie(movie_id)
    try:
        movie_data = await tmdb_service.detail(movie_id)
        add_watch_history(movie_id=movie_data.id, title=movie_data.title)
        return movie_data
    except Exception as exc:
        print(f"[TMDB fallback] movie detail failed: {exc}", flush=True)
        return _fallback_movie(movie_id)


@router.get("/feed", response_model=list[Post])
async def get_feed(
    refresh: bool = False,
    sort_by: str = Query("popularity", description="popularity or rating"),
):
    local_pref = get_user_preference()
    history_titles = get_watch_history_titles()

    if _has_preferences(local_pref):
        try:
            posts = await _preference_posts(local_pref)
            if posts:
                return posts
        except Exception as exc:
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
    except Exception as exc:
        print(f"[Agent fallback] feed failed: {exc}", flush=True)
        return _fallback_posts()


@router.get("/discovery", response_model=list[Movie])
async def get_discovery(page: int = 1):
    if not settings.tmdb_api_key:
        return FALLBACK_MOVIES
    try:
        movies = await tmdb_service.popular(page=page)
        return movies or FALLBACK_MOVIES
    except Exception as exc:
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
    return {"ok": True}
