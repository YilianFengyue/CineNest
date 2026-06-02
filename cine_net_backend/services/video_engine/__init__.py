"""Member A video source engine.

The implementation uses a small provider/rule layer inspired by Kazumi's
source-driven design, adapted to MacCMS JSON APIs.
"""

from .engine import (
    DEMO_VIDEO_URL,
    bilibili_search,
    parse_source,
    search_sources,
)

__all__ = [
    "DEMO_VIDEO_URL",
    "search_sources",
    "parse_source",
    "bilibili_search",
]
