"""CineNest 后端入口。

启动：
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
文档：
    http://127.0.0.1:8000/docs
"""
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from config import settings
from db import init_db
from routers import (
    agent,
    bili,
    catalog,
    chat,
    feed,
    forum,
    health,
    local_videos,
    microdesign,
    news,
    phone,
    play,
    poster,
    resources,
    sources,
    taste_dna,
    uploads,
)
from services.resources import get_resource_aggregator


@asynccontextmanager
async def lifespan(_: FastAPI):
    """启动时初始化存储与资源 Provider；LLM 保持懒加载。"""

    print("========= [SQLite] 正在检查并初始化本地数据库... =========", flush=True)
    init_db()
    print("========= [SQLite] 数据库初始化/检查成功！ =========", flush=True)
    get_resource_aggregator()
    yield


app = FastAPI(title="CineNest Backend", version="1.2.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request, call_next):
    print(f"\n>>> [收到请求] {request.method} {request.url.path}", flush=True)
    response = await call_next(request)
    print(f"<<< [请求结束] 状态码: {response.status_code}\n", flush=True)
    return response


@app.get("/api/ping_debug")
async def ping_debug():
    print("\n!!!!!!!!!! PONG SUCCESS !!!!!!!!!!\n", flush=True)
    return {"message": "pong", "status": "I AM THE RIGHT FILE"}


@app.get("/api/proxy/image", tags=["proxy (共建)"])
async def proxy_image(url: str):
    """图片代理：后端代为下载 TMDB 图片并转发给 App。"""

    if not url:
        return Response(status_code=400)
    try:
        async with httpx.AsyncClient(verify=False, trust_env=True) as client:
            resp = await client.get(url, timeout=10.0)
            resp.raise_for_status()
            return Response(content=resp.content, media_type=resp.headers.get("content-type"))
    except Exception as exc:  # noqa: BLE001
        print(f"图片中转失败: {url}, 错误: {exc}", flush=True)
        return Response(status_code=502)


@app.get("/console/phone", tags=["phone (AutoGLM)"])
async def phone_console():
    """AutoGLM 手机任务 HTML 测试台。"""

    return FileResponse(settings.static_phone_console_path)


app.include_router(health.router)
app.include_router(resources.router)
app.include_router(catalog.router)
app.include_router(microdesign.router)
app.include_router(agent.router)
app.include_router(bili.router)
app.include_router(feed.router)
app.include_router(forum.router)
app.include_router(sources.router)
app.include_router(poster.router)
app.include_router(news.router)
app.include_router(play.router)
app.include_router(chat.router)
app.include_router(uploads.router)
app.include_router(phone.router)
app.include_router(local_videos.router)
app.include_router(taste_dna.router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
