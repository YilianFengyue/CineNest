"""成员 C：影视资讯采集骨架（对应 F12）。

设计：定时/手动触发，网页搜索最新影视资讯（新片、评分变动、热点），整理成资讯帖子。
真实实现由成员 C 填充。
"""
from __future__ import annotations


async def fetch_news(limit: int = 5) -> list[dict]:
    """TODO(C): 采集 + 整理资讯。返回 [{title, summary, source}]。"""
    raise NotImplementedError("成员 C：资讯采集")
