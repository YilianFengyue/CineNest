"""AutoGLM 手机子 Agent REST 与 WebSocket 端点。"""
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

from services.phone import get_phone_runtime

router = APIRouter(tags=["phone (AutoGLM)"])


class PhoneConfigUpdate(BaseModel):
    enabled: bool | None = None
    model_base_url: str | None = None
    model_name: str | None = None
    api_key: str | None = None
    device_type: str | None = Field(default=None, pattern="^(adb|hdc)$")
    device_id: str | None = None
    max_steps: int | None = Field(default=None, ge=1, le=300)


class PhoneTaskRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=1000)
    thread_id: str = Field(default="", max_length=128)
    parent_task_id: str = Field(default="", max_length=128)
    success_criteria: str = Field(default="", max_length=1000)
    device_type: str | None = Field(default=None, pattern="^(adb|hdc)$")
    device_id: str | None = None
    max_steps: int | None = Field(default=None, ge=1, le=300)


class ContinueTaskRequest(BaseModel):
    instruction: str = Field(min_length=1, max_length=1000)


class ApproveTaskRequest(BaseModel):
    approved: bool = True


@router.get("/api/phone/config")
async def phone_config() -> dict[str, Any]:
    """读取运行期 AutoGLM 配置。不会返回明文 API Key。"""

    runtime = get_phone_runtime()
    return runtime.config.to_dict()


@router.post("/api/phone/config")
async def update_phone_config(payload: PhoneConfigUpdate) -> dict[str, Any]:
    """临时更新运行期配置，便于 HTML 控制台验链路；不写入 .env。"""

    runtime = get_phone_runtime()
    runtime.config.update(payload.model_dump(exclude_none=True))
    return runtime.config.to_dict()


@router.get("/api/phone/status")
async def phone_status() -> dict[str, Any]:
    """当前手机任务状态。"""

    runtime = get_phone_runtime()
    task = runtime.active_task
    return {
        "config": runtime.config.to_dict(),
        "running": runtime.is_running,
        "task": task.to_dict() if task else None,
    }


@router.get("/api/phone/devices")
async def list_devices(device_type: str | None = Query(default=None, pattern="^(adb|hdc)$")) -> dict[str, Any]:
    """列出 ADB 或 HDC 连接的设备。"""

    return get_phone_runtime().list_devices(device_type)


@router.get("/api/phone/tasks")
async def list_tasks(
    status: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict[str, Any]:
    """列出最近手机任务。"""

    tasks = get_phone_runtime().list_tasks(status=status, limit=limit)
    return {"tasks": [task.to_dict(include_steps=False) for task in tasks]}


@router.post("/api/phone/tasks")
async def start_phone_task(payload: PhoneTaskRequest) -> dict[str, Any]:
    """手动触发手机任务（不经主 Agent）。"""

    runtime = get_phone_runtime()
    try:
        task = await runtime.start_task(
            payload.objective,
            thread_id=payload.thread_id,
            parent_task_id=payload.parent_task_id,
            success_criteria=payload.success_criteria,
            device_type=payload.device_type,
            device_id=payload.device_id,
            max_steps=payload.max_steps,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return task.to_dict(include_steps=False)


@router.post("/api/phone/task")
async def start_phone_task_legacy(payload: dict[str, Any]) -> dict[str, Any]:
    """兼容旧 `/api/phone/task`：接受 `{task}` 或 `{objective}`。"""

    objective = str(payload.get("objective") or payload.get("task") or "").strip()
    if not objective:
        raise HTTPException(status_code=422, detail="objective/task 不能为空")
    req = PhoneTaskRequest(
        objective=objective,
        thread_id=str(payload.get("thread_id") or ""),
        success_criteria=str(payload.get("success_criteria") or ""),
        device_type=payload.get("device_type"),
        device_id=payload.get("device_id"),
        max_steps=payload.get("max_steps"),
    )
    return await start_phone_task(req)


@router.get("/api/phone/tasks/{task_id}")
async def get_phone_task(task_id: str) -> dict[str, Any]:
    """读取任务、步骤和最近事件。"""

    runtime = get_phone_runtime()
    try:
        return runtime.inspect_task(task_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/api/phone/tasks/{task_id}/continue")
async def continue_phone_task(task_id: str, payload: ContinueTaskRequest) -> dict[str, Any]:
    """追加后续指令；已完成任务会派生新任务。"""

    runtime = get_phone_runtime()
    try:
        task = await runtime.continue_task(task_id, payload.instruction)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return task.to_dict(include_steps=False)


@router.post("/api/phone/tasks/{task_id}/cancel")
async def cancel_phone_task(task_id: str) -> dict[str, Any]:
    """取消指定任务。"""

    if get_phone_runtime().cancel_task(task_id):
        return {"cancelled": True, "task_id": task_id}
    raise HTTPException(status_code=404, detail="没有可取消的任务")


@router.post("/api/phone/cancel")
async def cancel_active_phone_task() -> dict[str, Any]:
    """兼容旧取消接口：取消当前任务。"""

    if get_phone_runtime().cancel_task():
        return {"cancelled": True}
    raise HTTPException(status_code=404, detail="没有正在执行的任务")


@router.post("/api/phone/tasks/{task_id}/approve")
async def approve_phone_task(task_id: str, payload: ApproveTaskRequest) -> dict[str, Any]:
    """处理敏感操作确认。"""

    if get_phone_runtime().approve_task(task_id, payload.approved):
        return {"ok": True, "approved": payload.approved, "task_id": task_id}
    raise HTTPException(status_code=409, detail="任务当前不在等待确认状态")


@router.post("/api/phone/tasks/{task_id}/takeover-done")
async def takeover_done(task_id: str) -> dict[str, Any]:
    """用户完成登录/验证码/权限等人工接管后继续。"""

    if get_phone_runtime().mark_takeover_done(task_id):
        return {"ok": True, "task_id": task_id}
    raise HTTPException(status_code=409, detail="任务当前不在等待人工接管状态")


@router.websocket("/ws/tasks")
async def task_events_ws(ws: WebSocket):
    """手机任务事件流。聊天 WS 与任务 WS 分离，避免长任务阻塞对话。"""

    runtime = get_phone_runtime()
    await ws.accept()
    queue = runtime.subscribe()
    try:
        await ws.send_json(
            {
                "type": "tasks_snapshot",
                "data": {
                    "tasks": [task.to_dict(include_steps=False) for task in runtime.list_tasks(limit=20)],
                    "config": runtime.config.to_dict(),
                },
            }
        )
        async for event in runtime.iter_events(queue):
            await ws.send_json({"type": event.type, "data": event.to_dict()})
    except WebSocketDisconnect:
        pass
    finally:
        runtime.unsubscribe(queue)
