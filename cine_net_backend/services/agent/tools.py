# services/agent/tools.py
from typing import List, Dict, Any
from services.tmdb import tmdb_service
from models.schemas import Movie

# ============================================================================
# 1. 显式定义大模型可识别的工具元数据元组（JSON Schema）
# ============================================================================

TMDB_POPULAR_SCHEMA = {
    "type": "function",
    "function": {
        "name": "fetch_tmdb_popular_movies",
        "description": "当用户想要了解当前全球最新、最热门、处于流行趋势的电影列表时调用此工具。",
        "parameters": {
            "type": "object",
            "properties": {
                "page": {
                    "type": "integer",
                    "description": "拉取的页码，默认传入 1 即可",
                    "default": 1
                }
            }
        }
    }
}

TMDB_TOP_RATED_SCHEMA = {
    "type": "function",
    "function": {
        "name": "fetch_tmdb_top_rated_movies",
        "description": "当用户想要寻找影迷公认的经典、高分神作、口碑极佳的必看电影列表时调用此工具。",
        "parameters": {
            "type": "object",
            "properties": {
                "page": {
                    "type": "integer",
                    "description": "拉取的页码，默认传入 1 即可",
                    "default": 1
                }
            }
        }
    }
}

TMDB_SEARCH_SCHEMA = {
    "type": "function",
    "function": {
        "name": "search_tmdb_movies",
        "description": "当用户有明确的搜索意图、特定的主题要求，或者偏好(liked_genres/free_text)中明确指出了想看的类型（如爱情、科幻、战争等）时，必须调用此工具提取核心词进行搜索。",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "从用户偏好中提取出的最核心搜索关键词，例如：'爱情', '科幻', '烧脑反转' 等"
                },
                "page": {
                    "type": "integer",
                    "description": "拉取的页码，默认传入 1",
                    "default": 1
                }
            },
            "required": ["query"]
        }
    }
}


# ============================================================================
# 2. 编写工具的具体异步执行逻辑
# ============================================================================

async def fetch_tmdb_popular_movies(page: int = 1) -> List[Dict[str, Any]]:
    """真实拉取热门电影并转化为大模型轻量级上下文"""
    print(" [Agent Tool 日志] ──> 大模型选择触发了：【获取热门电影工具】")
    movies: List[Movie] = await tmdb_service.popular(page=page)
    # 只要前 5 部精选，控制 Token 长度以满足响应 < 15s 限制
    return [_minimize_movie_data(m) for m in movies[:5]]


async def fetch_tmdb_top_rated_movies(page: int = 1) -> List[Dict[str, Any]]:
    """真实拉取高分神作并转化为大模型轻量级上下文"""
    print(" [Agent Tool 日志] ──> 大模型选择触发了：【获取高分电影工具】")
    movies: List[Movie] = await tmdb_service.top_rated(page=page)
    return [_minimize_movie_data(m) for m in movies[:5]]


async def search_tmdb_movies(query: str, page: int = 1) -> List[Dict[str, Any]]:
    """根据关键词搜索电影并转化为大模型轻量级上下文"""
    print(f" [Agent Tool 日志] ──> 大模型极其聪明地触发了：【关键词搜索工具】，提取出的搜索内容：'{query}'")
    movies: List[Movie] = await tmdb_service.search(query=query, page=page)

    # 【非常重要的容错保护】：如果 TMDB 官方没有搜到这个奇葩关键词，返回一个兜底的假数据，防止大模型没东西处理而崩溃
    if not movies:
        print(f" [Agent Tool 警告] ──> TMDB 未找到关于 '{query}' 的内容。")
        return [{"id": 0, "title": "无结果", "genres": [], "rating": 0,
                 "overview": f"未找到相关电影，请告诉用户换个关键词试试"}]

    return [_minimize_movie_data(m) for m in movies[:5]]


def _minimize_movie_data(movie: Movie) -> Dict[str, Any]:
    """精简电影字段，为大模型省钱并加速推理"""
    return {
        "id": movie.id,
        "title": movie.title,
        "genres": movie.genres,
        "rating": movie.rating,
        "overview": movie.overview[:60] + "..." if movie.overview else "暂无简介"
    }


# ============================================================================
# 3. 建立工具名称到函数的映射字典与导出清单（解耦核心）
# ============================================================================

AVAILABLE_TOOLS = {
    "fetch_tmdb_popular_movies": fetch_tmdb_popular_movies,
    "fetch_tmdb_top_rated_movies": fetch_tmdb_top_rated_movies,
    "search_tmdb_movies": search_tmdb_movies
}

# 导出给大模型的完整工具集，现在包含三个可用工具！
AGENT_TOOLS_MANIFEST = [TMDB_POPULAR_SCHEMA, TMDB_TOP_RATED_SCHEMA, TMDB_SEARCH_SCHEMA]