"""成员 C 的 API 路由：AI 对话（WebSocket）+ 影视资讯。

WebSocket 当前回显 + 占位推荐；真实逻辑接入 services/agent + services/news。
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["chat & news (成员C)"])


@router.get("/api/news")
async def get_news():
    """资讯列表。TODO(C): 资讯采集 Agent。"""
    return [
        {
            "title": f"示例影视资讯 {i}",
            "summary": "占位摘要，真实数据接入资讯采集后替换。",
            "source": "https://example.com",
        }
        for i in range(5)
    ]


@router.websocket("/ws/chat")
async def chat_ws(ws: WebSocket):
    """对话 WebSocket。TODO(C): 接入 LangChain Agent，streaming 输出 + 内嵌推荐卡片。"""
    await ws.accept()
    try:
        while True:
            msg = await ws.receive_text()
            # 占位：原样回显 + 提示
            await ws.send_json({
                "role": "assistant",
                "content": f"（占位回复）收到：{msg}",
                "movies": [],
            })
    except WebSocketDisconnect:
        pass
