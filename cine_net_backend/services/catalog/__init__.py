"""影视资料 Catalog：豆瓣、TMDB 等可配置 Provider。"""

from .service import CatalogService, get_catalog_service

__all__ = ["CatalogService", "get_catalog_service"]
