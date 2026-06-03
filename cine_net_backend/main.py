"""CineNest 后端入口。

启动：
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
文档：
    http://127.0.0.1:8000/docs
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import agent, catalog, chat, feed, health, microdesign, news, play, poster, resources, sources, uploads
from db import init_db
from services.resources import get_resource_aggregator


@asynccontextmanager
async def lifespan(_: FastAPI):
    """启动时加载 Provider 注册表；LLM 保持懒加载，未填 Key 也能检索资源。"""

    init_db()
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

app.include_router(health.router)
app.include_router(resources.router)
app.include_router(catalog.router)
app.include_router(microdesign.router)
app.include_router(agent.router)
app.include_router(feed.router)
app.include_router(sources.router)
app.include_router(poster.router)
app.include_router(news.router)
app.include_router(play.router)
app.include_router(chat.router)
app.include_router(uploads.router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
