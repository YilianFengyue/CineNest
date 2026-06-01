"""成员 C 的 API 路由：Micro Design 海报。

当前返回占位 URL；真实逻辑接入 services/poster（HTML 模板 + 截图）。
"""
from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["poster (成员C)"])


@router.get("/poster/{movie_id}")
async def get_poster(movie_id: int, style: str = "auto"):
    """返回 Micro Design 海报图 URL。TODO(C): 模板渲染 + 截图生成。"""
    return {
        "movie_id": movie_id,
        "style": style,
        "poster_url": f"https://placeholder/poster/{movie_id}.png",
    }
