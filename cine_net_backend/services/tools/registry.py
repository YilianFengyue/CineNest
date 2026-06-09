"""集中注册 Agent 工具，后续新增 Provider 或 RAG 工具从这里接入。"""
from __future__ import annotations

from langchain_core.tools import BaseTool

from .catalog import (
    browse_catalog_hot,
    build_catalog_microdesign_poster,
    build_recommendation_feed,
    search_catalog_movies,
)
from .debate import debate_movie_recommendation
from .interactive import build_interactive_answer
from .media import build_microdesign_posts, get_playable_resource_detail, search_playable_resources
from .news import collect_movie_news, generate_movie_news
from .system import get_backend_status


def get_agent_tools() -> list[BaseTool]:
    return [
        get_backend_status,
        search_playable_resources,
        get_playable_resource_detail,
        build_microdesign_posts,
        browse_catalog_hot,
        search_catalog_movies,
        build_recommendation_feed,
        build_catalog_microdesign_poster,
        build_interactive_answer,
        debate_movie_recommendation,
        collect_movie_news,
        generate_movie_news,
    ]
