"""兼容旧前端契约的视频源 API。底层已经切换到真实 MacCMS 聚合层。"""
from fastapi import APIRouter, HTTPException

from services.resources import get_resource_aggregator

router = APIRouter(prefix="/api", tags=["sources"])


@router.get("/sources/search")
async def search_sources(movie_name: str):
    """按电影名搜索真实资源，保留旧 URL 供 Flutter 后续联调。"""

    response = await get_resource_aggregator().search(movie_name)
    return [
        {
            "id": f"{source.provider_id}:{source.remote_id}",
            "name": f"{source.provider_name} · {item.title}",
            "quality": source.remarks or None,
            "type": "web",
            "cover": source.cover_url or None,
        }
        for item in response.items
        for source in item.sources
    ]


@router.get("/sources/parse")
async def parse_source(source_id: str):
    """解析 `provider_id:remote_id`，返回第一条可播放剧集。"""

    if ":" not in source_id:
        raise HTTPException(status_code=400, detail="source_id 格式应为 provider_id:remote_id")
    provider_id, remote_id = source_id.split(":", maxsplit=1)
    try:
        detail = await get_resource_aggregator().detail(provider_id, remote_id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"视频源解析失败: {exc}") from exc
    for line in detail.play_lines:
        if line.episodes:
            first = line.episodes[0]
            return {
                "id": source_id,
                "name": f"{detail.provider_name} · {line.name} · {first.name}",
                "quality": detail.remarks or None,
                "type": "web",
                "play_url": first.play_url,
                "cover": detail.cover_url or None,
            }
    raise HTTPException(status_code=404, detail="该资源未解析出 HTTP(S) 播放地址")


@router.get("/bilibili/search")
async def bilibili_search(keyword: str):
    """TODO(A): Step 2 接入 B站公开搜索与用户授权能力。"""

    return []
