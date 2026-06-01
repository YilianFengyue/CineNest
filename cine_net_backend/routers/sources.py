"""成员 A 的 API 路由：视频源搜索 / 解析 / B站搜索。

当前为 mock；真实逻辑接入 services/video_engine。
"""
from fastapi import APIRouter

from models import VideoSource

router = APIRouter(prefix="/api", tags=["sources (成员A)"])


@router.get("/sources/search", response_model=list[VideoSource])
async def search_sources(movie_name: str):
    """按电影名搜索可用视频源。TODO(A): 视频源规则引擎。"""
    return [
        VideoSource(id="line1", name="线路1", quality="1080P", type="web"),
        VideoSource(id="bili1", name="B站解说", type="bilibili",
                    cover="https://placeholder", play_count=12000),
    ]


@router.get("/sources/parse", response_model=VideoSource)
async def parse_source(source_id: str):
    """解析某个源得到可播放地址。TODO(A): 解析网页提取 m3u8/mp4。"""
    return VideoSource(
        id=source_id,
        name="线路1",
        quality="1080P",
        type="web",
        play_url="https://example.com/sample.m3u8",
    )


@router.get("/bilibili/search", response_model=list[VideoSource])
async def bilibili_search(keyword: str):
    """B站搜索「电影名 + 解说」。TODO(A): WBI 签名 + 取流。"""
    return [
        VideoSource(id="BV1xx", name=f"{keyword} 深度解说", type="bilibili",
                    cover="https://placeholder", play_count=88000),
    ]
