"""成员 B 推荐入口的主 Agent 兼容层。

历史背景：远端 B 曾有一套 DeepSeek 直连的 client/engine/tools。合并后不再保留第二套
Agent，而是把 B 需要的 `movie_agent_service.get_personalized_feed()` 挂回 C 的
`services.agent` 包内，继续服务 `/api/feed`，让前端契约不变。
"""
from __future__ import annotations

import re

from config import settings
from models.schemas import Movie, Post, ScenarioResponse
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


_GENRE_NAME_TO_ID = {
    "动作": 28, "冒险": 12, "动画": 16, "喜剧": 35, "犯罪": 80, "纪录": 99, "剧情": 18,
    "家庭": 10751, "奇幻": 14, "历史": 36, "恐怖": 27, "音乐": 10402, "悬疑": 9648,
    "爱情": 10749, "科幻": 878, "电视电影": 10770, "惊悚": 53, "战争": 10752, "西部": 37
}


import asyncio
import time
from services.catalog.cache import TTLCache

# 1. 增加语义缓存：存储 scenario -> genre_text 的映射
_SCENARIO_CACHE = TTLCache(ttl_seconds=3600)  # 缓存 1 小时

class MovieAgentService:
    """B 模块 `/api/feed` 的兼容服务，统一归入 C 主 Agent 体系。"""

    async def get_personalized_feed(self, user_preference_prompt: str, scenario: str | None = None) -> list[Post]:
        """返回 B 前端需要的 `list[Post]`，支持可选的场景化推荐。"""

        movies, debug_info = await self._candidate_movies_with_trace(user_preference_prompt, scenario)
        if not movies:
            return []
        reason_map = await self._agent_reason_map(user_preference_prompt, movies, scenario)
        return [
            Post(
                movie=movie,
                recommend_reason=reason_map.get(movie.id) or self._fallback_reason(movie),
                has_video_source=True,
                has_bilibili=True,
                debug_info=debug_info if i == 0 else None
            )
            for i, movie in enumerate(movies[:8])
        ]

    async def get_scenario_recommendation(self, user_preference_prompt: str, scenario: str) -> ScenarioResponse:
        """性能优化版：极致缩短响应耗时。"""
        start_time = time.time()
        try:
            # 策略 1: 检索与推理分离 + 缓存
            movies, debug_info = await self._candidate_movies_with_trace(user_preference_prompt, scenario)
            print(f"[Performance] Step 1 (Search): {time.time() - start_time:.2f}s", flush=True)

            if not movies:
                return ScenarioResponse(posts=[], debug_info=debug_info)

            # 策略 2: 严格超时保护的理由生成
            # 限制理由生成仅针对前 3 部电影，且设置 6 秒硬超时
            reason_start = time.time()
            reason_map = {}
            try:
                # 使用 asyncio.wait_for 强制超时
                reason_map = await asyncio.wait_for(
                    self._agent_reason_map(user_preference_prompt, movies[:3], scenario),
                    timeout=6.0
                )
            except asyncio.TimeoutError:
                print("[Performance] Reason generation timed out, using fallback", flush=True)
            except Exception as e:
                print(f"[Performance] Reason generation error: {e}", flush=True)

            print(f"[Performance] Step 2 (Reasons): {time.time() - reason_start:.2f}s", flush=True)

            # 策略 3: 快速模版组装
            posts = []
            for i, movie in enumerate(movies[:8]):
                # 前几部有 AI 理由，后面的全走确定性模版
                reason = reason_map.get(movie.id) or self._fallback_reason(movie)
                posts.append(Post(
                    movie=movie,
                    recommend_reason=reason,
                    has_video_source=True,
                    has_bilibili=True
                ))

            print(f"[Performance] Total E2E Time: {time.time() - start_time:.2f}s", flush=True)
            return ScenarioResponse(posts=posts, debug_info=debug_info)

        except Exception as e:
            print(f"[Scenario Error] {e}", flush=True)
            return ScenarioResponse(posts=[], debug_info=f"服务繁忙，请稍后重试 ({e})")

    async def _candidate_movies_with_trace(self, prompt: str, scenario: str | None = None) -> tuple[list[Movie], str]:
        if not settings.tmdb_api_key:
            return [], "TMDB API Key 未配置"

        # 命中缓存逻辑
        cached_genres = _SCENARIO_CACHE.get(scenario) if scenario else None
        if scenario and cached_genres:
            genres_text = cached_genres
            print(f"[Cache] Hit scenario mapping: {scenario} -> {genres_text}", flush=True)
        elif scenario:
            # 增加映射超时保护
            try:
                genres_text = await asyncio.wait_for(self._smart_search_query(scenario), timeout=5.0)
                _SCENARIO_CACHE.set(scenario, genres_text)
            except:
                genres_text = scenario # 失败则原样搜索
        else:
            genres_text = self._search_query(prompt)

        genre_ids = []
        matched_names = []
        for name in re.split(r"[\s,，、]", genres_text):
            name = name.strip()
            if name in _GENRE_NAME_TO_ID:
                genre_ids.append(_GENRE_NAME_TO_ID[name])
                matched_names.append(name)

        if genre_ids:
            debug_info = f"AI 已识别场景并匹配分类：{'、'.join(matched_names)}"
            movies = await tmdb_service.discover_by_genres(genre_ids)
            if movies:
                return movies, debug_info

        # 兜底：如果没匹配到 Genre，尝试直接搜索
        debug_info = f"AI 将‘{scenario}’解析为关键词：{genres_text}"
        movies = await tmdb_service.search(genres_text)
        if movies:
            return movies, debug_info

        return await tmdb_service.popular(), f"未能精准匹配‘{scenario}’，为你推荐当前热门内容"

    async def _candidate_movies(self, prompt: str, scenario: str | None = None) -> list[Movie]:
        movies, _ = await self._candidate_movies_with_trace(prompt, scenario)
        return movies

    async def _smart_search_query(self, scenario: str) -> str:
        """使用 LLM 将场景语义化映射为 1-3 个最相关的分类。"""
        if not is_llm_configured("default"):
            return scenario

        genre_list = ", ".join(_GENRE_NAME_TO_ID.keys())
        message = (
            "你是一个电影策展专家。请分析用户当前的心情或场景，从以下预设分类中选出 1-3 个最契合的：\n"
            f"{genre_list}\n"
            "输出要求：只返回分类名称，多个名称用空格分隔，不要有任何其他文字。"
            f"\n用户场景描述：{scenario}"
        )
        try:
            result = await invoke_agent(message, thread_id="scenario-mapping", model="default")
            return result.answer.strip()
        except Exception as exc:  # noqa: BLE001
            print(f"[Main Agent scenario] mapping failed: {exc}", flush=True)
            return scenario

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

    async def _agent_reason_map(
        self,
        prompt: str,
        movies: list[Movie],
        scenario: str | None = None,
    ) -> dict[int, str]:
        """主 Agent 可用时让它参与推荐解释；失败时走确定性兜底文案。"""

        if not is_llm_configured("default"):
            return {}
        titles = "、".join(f"{movie.id}:{movie.title}" for movie in movies[:8])
        context = f"用户当前的心情或场景是：{scenario} (这是最高优先级)\n" if scenario else ""
        pref_context = f"用户的长期偏好是：{prompt} (仅作为次要参考)\n" if prompt else ""

        message = (
            "你正在为电影推荐生成一句话推荐理由。"
            f"{context}"
            f"{pref_context}"
            "请只基于下面候选电影，按 JSON 对象返回，键是 movie_id，值是 20 字以内中文理由。"
            "理由应极力贴合用户的‘心情或场景’。"
            f"\n候选电影:\n{titles}"
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
