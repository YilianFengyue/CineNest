# services/agent/service.py
#不关心模型怎么推理，
#只关心拿到大模型报告后，如何去匹配并映射成系统标准的 Post 实体
from typing import List
from models.schemas import Post, Movie
from services.tmdb import tmdb_service
from .engine import agent_engine


class MovieAgentService:
    """电影智能推荐 Agent 业务服务（彻底解耦的高级链版）"""

    async def get_personalized_feed(self, user_preference_prompt: str) -> List[Post]:
        """
        对外暴露的主入口：通过 Agent 跑通完整的智能推荐链条
        """
        # 1. 启动 Agent 认知和调用流
        agent_output = await agent_engine.run_recommendation_flow(user_preference_prompt)
        raw_context = agent_output["raw_movies_context"]
        ai_reasons = agent_output["ai_reasons"]

        # 2. 将 AI 生成的推荐词映射成大模型 O(1) 匹配字典
        reason_map = {item["movie_id"]: item["reason"] for item in ai_reasons if "movie_id" in item}

        # 3. 异步回填完整的 Movie 实体（包含演员、导演、海报等大图所需信息）
        posts = []
        for mini_movie in raw_context:
            movie_id = mini_movie["id"]
            try:
                # 触发完整的 TMDB 详情包装器，确保类型安全
                full_movie_data: Movie = await tmdb_service.detail(movie_id)

                # 获取大模型专门定制的一句话自然语言短评，若缺失则通过默认影评兜底
                recommend_reason = reason_map.get(
                    movie_id,
                    f"【系统智能策划】根据您的看片口味精准推荐，不容错过的《{full_movie_data.title}》。"
                )

                posts.append(Post(
                    movie=full_movie_data,
                    recommend_reason=recommend_reason,
                    has_video_source=True,  # 预留给 A 成员的 video_engine [cite: 64, 65]
                    has_bilibili=True  # 预留给 A 成员的 B站解说
                ))
            except Exception:
                continue  # 单部电影出错跳过，保证整个 Feed 流不会因为个别网络超时而整体崩溃

        return posts


movie_agent_service = MovieAgentService()