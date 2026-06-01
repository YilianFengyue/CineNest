"""成员 B：LangChain 推荐 Agent 骨架。

设计（对应《需求与计划书》F5）：
  Agent 持有一组 Tools（TMDB 搜索 / 详情 / B站搜索 / 视频源查询 / 用户偏好），
  按「读偏好 → 取候选 → 过滤排序 → 生成推荐语 → 查可看性 → 组装 Post」工作流产出帖子。

本文件只搭可扩展骨架：LLM 懒加载（无 key 也能 import），Tools 注册留占位。
真实链路由成员 B 填充。
"""
from __future__ import annotations

from functools import lru_cache

from config import settings


@lru_cache(maxsize=1)
def get_llm():
    """懒加载 DeepSeek LLM（兼容 OpenAI 格式）。仅在真正调用时才需要 API key。"""
    from langchain_openai import ChatOpenAI

    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.deepseek_api_key,
        base_url=settings.deepseek_base_url,
        temperature=0.7,
    )


def build_tools() -> list:
    """注册 Agent 工具集。TODO(B): 用 @tool 装饰器实现以下工具并返回。

    - search_tmdb(genre/keyword/sort)   搜索候选电影
    - get_movie_detail(movie_id)         电影详情
    - search_bilibili(keyword)           B站解说
    - search_video_source(movie_name)    视频源可看性
    - get_user_preference()              用户偏好
    """
    return []


async def recommend(preference: dict, count: int = 10) -> list[dict]:
    """生成推荐帖子（占位）。TODO(B): 用 LangGraph/AgentExecutor 编排上述工作流。

    返回的 dict 需符合 models.Post 结构，供 routers/feed.py 直接返回。
    """
    raise NotImplementedError("成员 B：在此接入 LangChain Agent 推荐链")
