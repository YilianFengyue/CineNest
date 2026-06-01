"""成员 A：视频源规则引擎骨架（对应 F4）。

设计：视频源以「规则/配置文件」形式管理，新增源不改代码（验收标准之一）。
  · search(movie_name)  → 遍历规则库搜索可用源
  · parse(source_id)    → 解析网页提取可播放 m3u8/mp4
  · B站：search → bvid → 取流（WBI 签名）

真实实现由成员 A 填充。规则建议放 rules/*.json 或 *.yaml。
"""
from __future__ import annotations


async def search_sources(movie_name: str) -> list[dict]:
    """TODO(A): 遍历视频源规则库搜索。返回符合 models.VideoSource 的 dict 列表。"""
    raise NotImplementedError("成员 A：视频源搜索")


async def parse_source(source_id: str) -> dict:
    """TODO(A): 解析源网页，提取可播放地址。"""
    raise NotImplementedError("成员 A：视频源解析")


async def bilibili_search(keyword: str) -> list[dict]:
    """TODO(A): B站搜索 + 取流（参考 PiliPlus 的 WBI 签名逻辑）。"""
    raise NotImplementedError("成员 A：B站搜索")
