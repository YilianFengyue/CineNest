"""CineNest 后端入口（共建）。

启动：
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
文档：
    http://127.0.0.1:8000/docs  (Swagger)

各模块路由分组挂载，成员各自在 routers/ 下维护自己的文件，互不交叉。
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import feed, sources, poster, chat

app = FastAPI(title="CineNest Backend", version="1.0.0")

# 手机端跨设备访问，开发期放开 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health", tags=["health (共建)"])
async def health():
    """健康检查（F7 连接测试）。"""
    return {"status": "ok", "service": "CineNest Backend", "version": "1.0.0"}


# ── 路由挂载 ──
app.include_router(feed.router)      # 成员 B
app.include_router(sources.router)   # 成员 A
app.include_router(poster.router)    # 成员 C
app.include_router(chat.router)      # 成员 C


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
