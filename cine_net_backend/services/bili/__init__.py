"""Bilibili content companion services."""

from .service import (
    get_article_markdown,
    get_hot_videos,
    get_movie_videos,
    get_rank,
    get_up_info,
    get_up_videos,
    get_video_detail,
    get_video_related,
    get_weekly_hot,
    search_articles,
    search_up_users,
    search_videos,
)

__all__ = [
    "get_article_markdown",
    "get_hot_videos",
    "get_movie_videos",
    "get_rank",
    "get_up_info",
    "get_up_videos",
    "get_video_detail",
    "get_video_related",
    "get_weekly_hot",
    "search_articles",
    "search_up_users",
    "search_videos",
]
