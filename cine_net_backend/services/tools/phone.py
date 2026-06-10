"""AutoGLM 手机子 Agent 工具组。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.phone import get_phone_runtime


def _dump(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False)


@tool
async def start_phone_task(
    objective: str,
    success_criteria: str = "",
    device_type: str = "",
    device_id: str = "",
    max_steps: int = 0,
) -> str:
    """启动一个异步 AutoGLM 手机任务，并立即返回 task_id。

    Args:
        objective: 要交给手机子 Agent 执行的自然语言目标。
        success_criteria: 可选验收标准，便于主 Agent 后续 inspect 判断是否达成。
        device_type: 可选设备类型，adb 表示 Android，hdc 表示 HarmonyOS。
        device_id: 可选设备 ID；为空时使用配置默认值或自动检测。
        max_steps: 可选最大步数；为空时使用配置默认值。
    """

    runtime = get_phone_runtime()
    try:
        task = await runtime.start_task(
            objective,
            success_criteria=success_criteria,
            device_type=device_type or None,
            device_id=device_id or None,
            max_steps=max_steps or None,
        )
    except Exception as exc:  # noqa: BLE001
        return _dump({"error": f"启动手机任务失败: {exc}"})
    return _dump(task.to_dict(include_steps=False))


@tool
async def execute_phone_task(task_description: str) -> str:
    """兼容旧提示词的手机任务启动工具。新任务请优先调用 start_phone_task。"""

    return await start_phone_task.ainvoke({"objective": task_description})


@tool
def get_phone_task_status(task_id: str) -> str:
    """查询某个手机任务的当前状态和最近一步。"""

    runtime = get_phone_runtime()
    task = runtime.get_task(task_id)
    if task is None:
        return _dump({"error": f"未知手机任务: {task_id}"})
    return _dump(task.to_dict())


@tool
def inspect_phone_task(task_id: str) -> str:
    """读取手机任务完整状态、最近事件和摘要，供主 Agent 判断下一步。"""

    runtime = get_phone_runtime()
    try:
        return _dump(runtime.inspect_task(task_id))
    except LookupError as exc:
        return _dump({"error": str(exc)})


@tool
async def continue_phone_task(task_id: str, instruction: str) -> str:
    """给正在运行或已结束的手机任务追加后续指令；已结束任务会派生新任务。"""

    runtime = get_phone_runtime()
    try:
        task = await runtime.continue_task(task_id, instruction)
    except Exception as exc:  # noqa: BLE001
        return _dump({"error": f"继续手机任务失败: {exc}"})
    return _dump(task.to_dict(include_steps=False))


@tool
def cancel_phone_task(task_id: str = "") -> str:
    """取消当前或指定手机任务。"""

    runtime = get_phone_runtime()
    ok = runtime.cancel_task(task_id or None)
    return _dump({"cancelled": ok, "task_id": task_id})


@tool
def list_phone_tasks(status: str = "", limit: int = 10) -> str:
    """列出最近的手机自动化任务。status 可为空或 running/done/failed/cancelled 等。"""

    runtime = get_phone_runtime()
    tasks = runtime.list_tasks(status=status or None, limit=limit)
    return _dump({"tasks": [task.to_dict(include_steps=False) for task in tasks]})
