"""成员 B 的 API 路由：推荐帖子流 / 详情 / 偏好 / 反馈。

当前为 mock 实现，保证前端 Day1 可联调；真实逻辑接入 services/agent + services/tmdb。
"""
from fastapi import APIRouter
from models import Post, Movie, UserPreference, Feedback
from fastapi import APIRouter, Query, HTTPException
from typing import List
from models.schemas import Post, Movie
from services.tmdb import tmdb_service  # 引入我们刚才创建的真实 TMDB 服务层
from services.agent.service import movie_agent_service  # 引入解耦后的 AI 业务层

router = APIRouter(prefix="/api", tags=["feed (成员B)"])


@router.get("/movie/{movie_id}", response_model=Movie)
async def get_movie(movie_id: int):
    """
    获取真实的电影详情。

    内部触发 TMDB /movie/{movie_id} 接口，并通过追加参数一次性带回
    导演(directors)与前5位核心演员(cast)的数据。
    """
    try:
        movie_data = await tmdb_service.detail(movie_id)
        return movie_data
    except HTTPException as e:
        # 传递自 client.py 抛出的标准 TMDB 错误（如 404 未找到）
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取电影详情失败: {str(e)}")


@router.get("/feed", response_model=List[Post])
async def get_feed(
        refresh: bool = False,
        mode: str = Query("popular", description="流类型: popular(热门), top_rated(高分神作)")
):
    """
    获取首页帖子流。
    不再使用原有的静态假数据，而是根据传入的 mode 参数，动态拉取 TMDB
    对应的实时电影列表，并将其包装为系统标准的 Post 模型返回给前端。
    """
    # 将前端的入参直接泛化转化为智能体可以阅读的自然语言提示词（后续 F6 阶段可以无缝引入用户真正的 SQLite 偏好数据） [cite: 308]
    if mode == "top_rated":
        user_preference_prompt = "我现在想看影迷公认的、评分极高的、殿堂级的经典口碑神作电影。"
    else:
        user_preference_prompt = "我想紧跟潮流，了解一下当前全球范围内最热门、热度最高的流行电影趋势。"

    try:
        # 一键呼叫解耦后的 Agent 链条
        posts = await movie_agent_service.get_personalized_feed(user_preference_prompt)
        return posts
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"CineAgent 基础链生成失败: {str(e)}")


@router.post("/preferences")
async def set_preferences(pref: UserPreference):
    """保存用户偏好。TODO(B): 落库 SQLite，作为推荐输入。"""
    return {"ok": True, "saved": pref.model_dump()}


@router.post("/feedback")
async def post_feedback(fb: Feedback):
    """喜欢/不感兴趣反馈。TODO(B): 影响后续推荐。"""
    return {"ok": True}
