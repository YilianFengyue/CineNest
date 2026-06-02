"""成员 B 的 API 路由：推荐帖子流 / 详情 / 偏好 / 反馈。

当前为 mock 实现，保证前端 Day1 可联调；真实逻辑接入 services/agent + services/tmdb。
"""
import sys
from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
from models.schemas import Post, Movie, UserPreference, Feedback
from services.tmdb import tmdb_service
from services.agent.service import movie_agent_service
from db.database import save_user_preference, get_user_preference, add_watch_history, get_watch_history_titles

router = APIRouter(prefix="/api", tags=["feed (成员B)"])


@router.get("/movie/{movie_id}", response_model=Movie)
async def get_movie(movie_id: int):
    """获取真实的电影详情，并悄悄记录观影历史"""
    try:
        movie_data = await tmdb_service.detail(movie_id)
        add_watch_history(movie_id=movie_data.id, title=movie_data.title)
        return movie_data
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取电影详情失败: {str(e)}")


@router.get("/feed", response_model=List[Post])
async def get_feed(
        refresh: bool = False,
        sort_by: str = Query("popularity", description="排序模式: popularity(热门度), rating(评分)")
):
    """
    获取首页帖子流。
    【核心逻辑重构】：严格遵循用户偏好进行全量搜索，不再受限于固定的热门/高分列表。
    """
    print(f"\n[HTTP 请求] 进入 get_feed, 排序模式: {sort_by}, 刷新: {refresh}", flush=True)

    # 1. 获取用户最真实的偏好
    local_pref = get_user_preference()
    history_titles = get_watch_history_titles()

    # 2. 构造“纯偏好驱动”的指令
    # 彻底放弃固定的 base_prompt，让 AI 深入理解用户的灵魂
    user_preference_prompt = f"【当前用户的个性化灵魂画像】\n"

    if local_pref.liked_genres:
        user_preference_prompt += f"- 钟爱的类型: {', '.join(local_pref.liked_genres)}\n"
    if local_pref.disliked_genres:
        user_preference_prompt += f"- 讨厌的类型: {', '.join(local_pref.disliked_genres)} (请务必严格避开)\n"
    if local_pref.free_text:
        user_preference_prompt += f"- 用户的内心独白: {local_pref.free_text}\n"

    if history_titles:
        user_preference_prompt += f"- 用户的足迹(已看): {', '.join(history_titles)}\n"

    user_preference_prompt += f"\n【任务】: 请严格根据以上画像，从全球影库中搜索并推荐电影。排序权重应侧重于: {'热度优先' if sort_by == 'popularity' else '评分优先'}。"

    try:
        # 调用重构后的 Agent 链
        posts = await movie_agent_service.get_personalized_feed(user_preference_prompt)
        return posts
    except Exception as e:
        print(f"[Agent 错误] 生成推荐失败: {e}", flush=True)
        raise HTTPException(status_code=500, detail=f"AI 推荐引擎执行失败: {str(e)}")


@router.get("/discovery", response_model=List[Movie])
async def get_discovery(page: int = 1):
    """
    首页探索：直接获取当前全球最热门的电影。
    这个接口不经过 AI Agent，响应极快，适合作为 App 启动首页。
    """
    print(f"\n[HTTP 请求] 进入 get_discovery, 页码: {page}", flush=True)
    try:
        movies = await tmdb_service.popular(page=page)
        return movies
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取探索数据失败: {str(e)}")


@router.post("/preferences")
async def set_preferences(pref: UserPreference):
    """保存用户偏好落库 SQLite"""
    try:
        # 【新加逻辑】调用持久化方法
        save_user_preference(pref)
        return {"ok": True, "saved": pref.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"保存偏好失败: {str(e)}")

@router.get("/preferences", response_model=UserPreference)
async def get_preferences():
    """获取当前用户的偏好设置（用于前端回显）"""
    try:
        # 调用 db/database.py 中的查询函数
        pref = get_user_preference()
        return pref
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取偏好失败: {str(e)}")

@router.post("/feedback")
async def post_feedback(fb: Feedback):
    """喜欢/不感兴趣反馈。TODO(B): 影响后续推荐。"""
    return {"ok": True}
