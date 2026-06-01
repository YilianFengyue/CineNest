"""成员 B：TMDB 客户端骨架。

封装影视数据采集（搜索 / 详情 / 热门 / Top Rated），统一中文 language=zh-CN。
真实实现用 httpx 异步调用，并把 poster_path 拼成完整 URL（settings.tmdb_image_base）。
"""
# services/tmdb/__init__.py
from services.tmdb.service import TMDBService

# 全局单例，避免重复创建 client 实例
tmdb_service = TMDBService()

__all__ = ["tmdb_service"]