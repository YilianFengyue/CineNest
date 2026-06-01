"""成员 C：Micro Design 海报生成骨架（对应 F8）。

设计：HTML 模板（Jinja2）+ 截图（playwright）生成专属海报。
  · 至少 3 套风格模板，按电影类型自动匹配（科幻→暗色赛博 / 文艺→暖色水彩 / 动作→高对比）。
真实实现由成员 C 填充，模板建议放 templates/*.html。
"""
from __future__ import annotations


async def generate_poster(movie: dict, style: str = "auto") -> str:
    """TODO(C): 渲染模板 + 截图，返回海报图 URL/路径。"""
    raise NotImplementedError("成员 C：海报生成")
