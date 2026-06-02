"""CineNest 后端入口（共建）。

启动：
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
文档：
    http://127.0.0.1:8000/docs  (Swagger)

各模块路由分组挂载，成员各自在 routers/ 下维护自己的文件，互不交叉。
"""
from contextlib import asynccontextmanager # 1. 引入上下文管理器
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import feed, sources, poster, chat
import httpx
from db.database import init_db
from fastapi import Response

# 3. 定义生命周期管理器
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("========= [SQLite] 正在检查并初始化本地数据库... =========")
    init_db()  # 执行建表逻辑
    print("========= [SQLite] 数据库初始化/检查成功！ =========")
    yield

app = FastAPI(title="CineNest Backend", version="1.0.0", lifespan=lifespan)

# ── 【全域请求监控中间件】 ──
@app.middleware("http")
async def log_requests(request, call_next):
    print(f"\n>>> [收到请求] {request.method} {request.url.path}", flush=True)
    response = await call_next(request)
    print(f"<<< [请求结束] 状态码: {response.status_code}\n", flush=True)
    return response

# ── 【紧急调试路径】 ──
@app.get("/api/ping_debug")
async def ping_debug():
    print("\n!!!!!!!!!! PONG SUCCESS !!!!!!!!!!\n", flush=True)
    return {"message": "pong", "status": "I AM THE RIGHT FILE"}

# ── 图片中转代理 (解决 Android 模拟器无法访问 TMDB 的问题) ──
@app.get("/api/proxy/image", tags=["proxy (共建)"])
async def proxy_image(url: str):
    """
    图片代理：后端代为下载 TMDB 图片并转发给 App。
    用法: /api/proxy/image?url=https://image.tmdb.org/...
    """
    if not url:
        return Response(status_code=400)

    try:
        async with httpx.AsyncClient(verify=False, trust_env=True) as client:
            # 使用后端电脑的代理环境请求图片
            resp = await client.get(url, timeout=10.0)
            resp.raise_for_status()
            return Response(content=resp.content, media_type=resp.headers.get("content-type"))
    except Exception as e:
        print(f"图片中转失败: {url}, 错误: {e}")
        return Response(status_code=502)

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
