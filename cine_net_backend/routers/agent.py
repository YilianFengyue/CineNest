"""Agent REST API。"""
from fastapi import APIRouter, HTTPException

from services.chat import add_message
from services.agent import invoke_agent
from services.agent.schemas import AgentInvokeRequest, AgentInvokeResponse
from services.llm import list_chat_models

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
