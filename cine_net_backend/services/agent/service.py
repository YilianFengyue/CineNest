"""成员 B 推荐入口的主 Agent 兼容层。

历史背景：远端 B 曾有一套 DeepSeek 直连的 client/engine/tools。合并后不再保留第二套
Agent，而是把 B 需要的 `movie_agent_service.get_personalized_feed()` 挂回 C 的
`services.agent` 包内，继续服务 `/api/feed`，让前端契约不变。
"""
from __future__ import annotations

import re

from config import settings
from models.schemas import Movie, Post
from services.llm import is_llm_configured
from services.tmdb import tmdb_service

from .factory import AgentServiceUnavailableError, invoke_agent


_GENRE_HINTS = (
    "动作",
    "冒险",
    "动画",
    "喜剧",
    "犯罪",
    "剧情",
    "家庭",
    "奇幻",
    "历史",
    "恐怖",
    "音乐",
    "悬疑",
    "爱情",
    "科幻",
    "惊悚",
    "战争",
    "西部",
)


class MovieAgentService:
    """B 模块 `/api/feed` 的兼容服务，统一归入 C 主 Agent 体系。"""

    async def get_personalized_feed(self, user_preference_prompt: str) -> list[Post]:
        """返回 B 前端需要的 `list[Post]`，不再直接调用 DeepSeek。"""

        movies = await self._candidate_movies(user_preference_prompt)
        if not movies:
            return []
        reason_map = await self._agent_reason_map(user_preference_prompt, movies)
        return [
            Post(
                movie=movie,
                recommend_reason=reason_map.get(movie.id) or self._fallback_reason(movie),
                has_video_source=True,
                has_bilibili=True,
            )
            for movie in movies[:8]
        ]

    async def _candidate_movies(self, prompt: str) -> list[Movie]:
        if not settings.tmdb_api_key:
            return []

        query = self._search_query(prompt)
        try:
            if query:
                movies = await tmdb_service.search(query)
                if movies:
                    return movies
            return await tmdb_service.popular()
        except Exception as exc:  # noqa: BLE001
            print(f"[Main Agent feed adapter] TMDB candidate failed: {exc}", flush=True)
            return []

    def _search_query(self, prompt: str) -> str:
        liked = re.search(r"- liked:\s*(.+)", prompt)
        if liked:
            for item in re.split(r"[,，、]", liked.group(1)):
                value = item.strip()
                if value:
                    return value
        for hint in _GENRE_HINTS:
            if hint in prompt:
                return hint
        return ""

    async def _agent_reason_map(self, prompt: str, movies: list[Movie]) -> dict[int, str]:
        """主 Agent 可用时让它参与推荐解释；失败时走确定性兜底文案。"""

        if not is_llm_configured("default"):
            return {}
        titles = "、".join(f"{movie.id}:{movie.title}" for movie in movies[:8])
        message = (
            "你正在为首页推荐 Feed 生成一句话推荐理由。"
            "请只基于下面候选电影和用户偏好，按 JSON 对象返回，键是 movie_id，值是 20 字以内中文理由。"
            f"\n用户偏好:\n{prompt}\n候选电影:\n{titles}"
        )
        try:
            result = await invoke_agent(message, thread_id="feed-compat", model="default")
        except AgentServiceUnavailableError:
            return {}
        except Exception as exc:  # noqa: BLE001
            print(f"[Main Agent feed adapter] reason generation failed: {exc}", flush=True)
            return {}
        return self._parse_reason_map(result.answer)

    def _parse_reason_map(self, answer: str) -> dict[int, str]:
        reason_map: dict[int, str] = {}
        for movie_id, reason in re.findall(r'"?(\d+)"?\s*[:：]\s*"([^"]{1,80})"', answer):
            reason_map[int(movie_id)] = reason.strip()
        return reason_map

    def _fallback_reason(self, movie: Movie) -> str:
        genre = " / ".join(movie.genres[:2]) if movie.genres else "影视"
        rating = f"{movie.rating:.1f}" if isinstance(movie.rating, (int, float)) else "暂无"
        return f"根据你的偏好筛选的{genre}片，TMDB 评分 {rating}。"


movie_agent_service = MovieAgentService()
