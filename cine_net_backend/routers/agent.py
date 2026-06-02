"""Agent REST API。"""
from fastapi import APIRouter, HTTPException

from services.agent import invoke_agent
from services.agent.schemas import AgentInvokeRequest, AgentInvokeResponse

router = APIRouter(prefix="/api/agent", tags=["agent"])


@router.post("/invoke", response_model=AgentInvokeResponse)
async def invoke(request: AgentInvokeRequest) -> AgentInvokeResponse:
    """调用可使用影视资源 Tools 的 CineNest Agent。"""

    try:
        return await invoke_agent(request.message, request.thread_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Agent 调用失败: {exc}") from exc
