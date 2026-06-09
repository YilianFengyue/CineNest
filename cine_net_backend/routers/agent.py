"""Agent REST API。"""
from fastapi import APIRouter, HTTPException

from services.chat import add_message
from services.agent import invoke_agent
from services.agent.schemas import AgentInvokeRequest, AgentInvokeResponse
from services.debate import DebateRecommendationEnvelope, DebateRecommendationRequest, build_debate_recommendation
from services.llm import list_chat_models
from services.memory import (
    AgentProfile,
    MemorySyncRequest,
    MemorySyncResponse,
    ProfileRebuildRequest,
    get_profile,
    rebuild_profile,
    remember_chat_signal,
    sync_frontend_memory,
)

router = APIRouter(prefix="/api/agent", tags=["agent"])


@router.get("/models")
async def list_models() -> list[dict]:
    """列出前端可选择的模型别名。"""

    return [item.model_dump() for item in list_chat_models()]


@router.post("/invoke", response_model=AgentInvokeResponse)
async def invoke(request: AgentInvokeRequest) -> AgentInvokeResponse:
    """调用可使用影视资源 Tools 的 CineNest Agent。"""

    try:
        add_message(
            request.thread_id,
            "user",
            request.message,
            model=request.model,
            attachments=[item.model_dump() for item in request.attachments],
        )
        remember_chat_signal("default", request.message)
        result = await invoke_agent(
            request.message,
            request.thread_id,
            model=request.model,
            attachments=request.attachments,
        )
        add_message(
            request.thread_id,
            "assistant",
            result.answer,
            model=request.model,
            attachments=[item.model_dump() for item in result.attachments],
            tool_calls=result.tool_calls,
        )
        return result
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Agent 调用失败: {exc}") from exc


@router.post("/memory/sync", response_model=MemorySyncResponse)
async def sync_memory(request: MemorySyncRequest) -> MemorySyncResponse:
    """同步 Flutter 本地观看历史/收藏到 PC 端长期记忆库。"""

    try:
        return sync_frontend_memory(request)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"同步长期记忆失败: {exc}") from exc


@router.get("/profile", response_model=AgentProfile)
async def profile(user_id: str = "default") -> AgentProfile:
    """读取用户长期画像，供设置页图表/WebView 渲染。"""

    try:
        return get_profile(user_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"读取画像失败: {exc}") from exc


@router.post("/profile/rebuild", response_model=AgentProfile)
async def rebuild(request: ProfileRebuildRequest) -> AgentProfile:
    """从长期记忆重新构建画像。"""

    try:
        return rebuild_profile(request.user_id, use_llm=request.use_llm)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"重建画像失败: {exc}") from exc


@router.post("/debate/recommend", response_model=DebateRecommendationEnvelope)
async def debate_recommend(request: DebateRecommendationRequest) -> DebateRecommendationEnvelope:
    """一次 LLM 调用模拟多专家辩论式影视推荐。"""

    try:
        return await build_debate_recommendation(request)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"生成推荐委员会结论失败: {exc}") from exc
