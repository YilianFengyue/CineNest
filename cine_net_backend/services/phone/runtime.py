"""异步 Phone Runtime：主 Agent 调度 AutoGLM 子 Agent 的执行层。"""
from __future__ import annotations

import asyncio
import threading
import time
import traceback
from dataclasses import dataclass, field
from typing import Any

from config import settings

from . import store
from .models import PhoneDeviceType, PhoneEvent, PhoneObservation, PhoneStep, PhoneTask


@dataclass
class RuntimePhoneConfig:
    enabled: bool = settings.phone_enabled
    model_base_url: str = settings.phone_model_base_url
    model_name: str = settings.phone_model_name
    api_key: str = settings.phone_api_key
    device_type: PhoneDeviceType = "hdc" if settings.phone_device_type == "hdc" else "adb"
    device_id: str = settings.phone_device_id
    max_steps: int = settings.phone_max_steps

    def to_dict(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "model_base_url": self.model_base_url,
            "model_name": self.model_name,
            "api_key_configured": bool(self.api_key),
            "device_type": self.device_type,
            "device_id": self.device_id,
            "max_steps": self.max_steps,
        }

    def update(self, data: dict[str, Any]) -> None:
        if "enabled" in data:
            self.enabled = bool(data["enabled"])
        if data.get("model_base_url") is not None:
            self.model_base_url = str(data["model_base_url"]).strip() or self.model_base_url
        if data.get("model_name") is not None:
            self.model_name = str(data["model_name"]).strip() or self.model_name
        if data.get("api_key") is not None:
            self.api_key = str(data["api_key"])
        if data.get("device_type") in ("adb", "hdc"):
            self.device_type = data["device_type"]
        if data.get("device_id") is not None:
            self.device_id = str(data["device_id"]).strip()
        if data.get("max_steps") is not None:
            self.max_steps = max(1, min(int(data["max_steps"]), 300))


@dataclass
class _WaitControl:
    kind: str
    message: str
    event: threading.Event = field(default_factory=threading.Event)
    approved: bool = False


class PhoneRuntime:
    """管理 AutoGLM 手机任务、事件广播与人工确认。

    同一时刻默认只跑一个手机任务，避免多任务同时抢同一台设备。聊天流不等待任务结束，
    任何 UI 通过 subscribe()/iter_events() 或 /ws/tasks 订阅进度。
    """

    def __init__(self) -> None:
        self.config = RuntimePhoneConfig()
        self._running_task_id: str | None = None
        self._tasks: dict[str, PhoneTask] = {}
        self._cancel_flags: set[str] = set()
        self._wait_controls: dict[str, _WaitControl] = {}
        self._subscribers: list[asyncio.Queue[PhoneEvent | None]] = []
        self._loop: asyncio.AbstractEventLoop | None = None
        self._lock = threading.RLock()

    @property
    def active_task(self) -> PhoneTask | None:
        if not self._running_task_id:
            return None
        return self.get_task(self._running_task_id)

    @property
    def is_running(self) -> bool:
        return self._running_task_id is not None

    def subscribe(self) -> asyncio.Queue[PhoneEvent | None]:
        queue: asyncio.Queue[PhoneEvent | None] = asyncio.Queue()
        self._subscribers.append(queue)
        return queue

    def unsubscribe(self, queue: asyncio.Queue) -> None:
        self._subscribers = [item for item in self._subscribers if item is not queue]

    @staticmethod
    async def iter_events(queue: asyncio.Queue[PhoneEvent | None]):
        while True:
            event = await queue.get()
            if event is None:
                break
            yield event

    def get_task(self, task_id: str, *, include_steps: bool = True) -> PhoneTask | None:
        task = self._tasks.get(task_id)
        if task is not None and include_steps:
            return task
        return store.get_task(task_id, include_steps=include_steps)

    def list_tasks(self, status: str | None = None, limit: int = 50) -> list[PhoneTask]:
        tasks = store.list_tasks(status=status, limit=limit)
        if self._running_task_id and all(item.id != self._running_task_id for item in tasks):
            active = self.active_task
            if active is not None:
                tasks.insert(0, active)
        return tasks[:limit]

    async def start_task(
        self,
        objective: str,
        device_id_legacy: str | None = None,
        *,
        thread_id: str = "",
        parent_task_id: str = "",
        success_criteria: str = "",
        device_type: str | None = None,
        device_id: str | None = None,
        max_steps: int | None = None,
    ) -> PhoneTask:
        if not self.config.enabled:
            raise RuntimeError("手机控制功能未启用，请在 .env 中配置 PHONE_ENABLED=true 或在控制台临时启用")
        if not self.config.api_key.strip():
            raise RuntimeError("AutoGLM API Key 未配置，请在 .env 填写 PHONE_API_KEY 或在控制台临时配置")
        if self._running_task_id:
            raise RuntimeError("已有手机任务在执行，请等待完成或取消后再试")

        self._loop = asyncio.get_running_loop()
        resolved_device_type: PhoneDeviceType = "hdc" if (device_type or self.config.device_type) == "hdc" else "adb"
        resolved_device_id = device_id if device_id is not None else device_id_legacy
        task = PhoneTask(
            thread_id=thread_id,
            parent_task_id=parent_task_id,
            objective=objective,
            success_criteria=success_criteria,
            device_type=resolved_device_type,
            device_id=(resolved_device_id if resolved_device_id is not None else self.config.device_id).strip(),
            max_steps=max_steps or self.config.max_steps,
        )
        with self._lock:
            self._running_task_id = task.id
            self._tasks[task.id] = task
            self._cancel_flags.discard(task.id)
        self._save_task(task)
        self._emit("task_created", task, {"task": task.to_dict(include_steps=False)})
        asyncio.create_task(self._run_task(task))
        return task

    # 兼容旧调用：manager.start_task(description, device_id)
    async def start_legacy_task(self, description: str, device_id: str | None = None) -> PhoneTask:
        return await self.start_task(description, device_id=device_id)

    def cancel_task(self, task_id: str | None = None) -> bool:
        resolved = task_id or self._running_task_id
        if not resolved:
            return False
        self._cancel_flags.add(resolved)
        control = self._wait_controls.get(resolved)
        if control is not None:
            control.event.set()
        task = self.get_task(resolved)
        if task is not None and task.status in {"queued", "running", "waiting_approval", "waiting_takeover"}:
            task.status = "cancelled"
            task.result = "用户取消"
            task.finished_at = time.time()
            task.updated_at = time.time()
            self._save_task(task)
            self._emit("task_cancelled", task, {"task": task.to_dict(include_steps=False)})
        return True

    # 兼容旧调用：manager.cancel()
    def cancel(self) -> bool:
        return self.cancel_task()

    async def continue_task(self, task_id: str, instruction: str) -> PhoneTask:
        task = self.get_task(task_id)
        if task is None:
            raise LookupError(f"未知手机任务: {task_id}")
        self._emit("task_instruction", task, {"instruction": instruction, "task": task.to_dict(include_steps=False)})
        if task.status in {"done", "failed", "cancelled"}:
            objective = f"继续此前手机任务：{task.objective}\n补充指令：{instruction}"
            return await self.start_task(
                objective,
                thread_id=task.thread_id,
                parent_task_id=task.id,
                success_criteria=task.success_criteria,
                device_type=task.device_type,
                device_id=task.device_id,
                max_steps=task.max_steps,
            )
        return task

    def approve_task(self, task_id: str, approved: bool = True) -> bool:
        control = self._wait_controls.get(task_id)
        if control is None or control.kind != "approval":
            return False
        control.approved = approved
        control.event.set()
        return True

    def mark_takeover_done(self, task_id: str) -> bool:
        control = self._wait_controls.get(task_id)
        if control is None or control.kind != "takeover":
            return False
        control.approved = True
        control.event.set()
        return True

    def inspect_task(self, task_id: str) -> dict[str, Any]:
        task = self.get_task(task_id)
        if task is None:
            raise LookupError(f"未知手机任务: {task_id}")
        events = [event.to_dict() for event in store.list_events(task_id, limit=50)]
        return {
            "task": task.to_dict(),
            "events": events,
            "summary": self._task_summary(task),
        }

    def list_devices(self, device_type: str | None = None) -> dict[str, Any]:
        resolved = "hdc" if (device_type or self.config.device_type) == "hdc" else "adb"
        try:
            from phone_agent.device_factory import DeviceType, set_device_type

            set_device_type(DeviceType.HDC if resolved == "hdc" else DeviceType.ADB)
            if resolved == "hdc":
                from phone_agent.hdc.connection import HDCConnection

                devices = HDCConnection().list_devices()
            else:
                from phone_agent.adb.connection import ADBConnection

                devices = ADBConnection().list_devices()
        except ImportError as exc:
            return {"device_type": resolved, "devices": [], "error": f"phone_agent 未安装: {exc}"}
        except Exception as exc:  # noqa: BLE001
            return {"device_type": resolved, "devices": [], "error": str(exc)}

        return {
            "device_type": resolved,
            "devices": [
                {
                    "id": getattr(item, "device_id", ""),
                    "status": getattr(item, "status", ""),
                    "type": getattr(getattr(item, "connection_type", None), "value", "unknown"),
                    "model": getattr(item, "model", ""),
                }
                for item in devices
            ],
        }

    async def _run_task(self, task: PhoneTask) -> None:
        try:
            await asyncio.to_thread(self._run_task_sync, task)
        except Exception as exc:  # noqa: BLE001
            task.status = "failed"
            task.error = str(exc)
            task.finished_at = time.time()
            task.updated_at = time.time()
            self._save_task(task)
            self._emit("task_failed", task, {"error": str(exc), "task": task.to_dict(include_steps=False)})
            traceback.print_exc()
        finally:
            with self._lock:
                if self._running_task_id == task.id:
                    self._running_task_id = None
                self._wait_controls.pop(task.id, None)
                self._cancel_flags.discard(task.id)

    def _run_task_sync(self, task: PhoneTask) -> None:
        try:
            from phone_agent import PhoneAgent
            from phone_agent.agent import AgentConfig
            from phone_agent.device_factory import DeviceType, set_device_type
            from phone_agent.model import ModelConfig
        except ImportError as exc:
            task.status = "failed"
            task.error = f"phone_agent 未安装: {exc}。请执行 pip install -e ../CodeReference/Open-AutoGLM"
            task.finished_at = time.time()
            task.updated_at = time.time()
            self._save_task(task)
            self._emit("task_failed", task, {"error": task.error, "task": task.to_dict(include_steps=False)})
            return

        set_device_type(DeviceType.HDC if task.device_type == "hdc" else DeviceType.ADB)
        agent = PhoneAgent(
            model_config=ModelConfig(
                base_url=self.config.model_base_url,
                api_key=self.config.api_key or "EMPTY",
                model_name=self.config.model_name,
                max_tokens=3000,
                temperature=0.0,
            ),
            agent_config=AgentConfig(
                max_steps=task.max_steps,
                device_id=task.device_id or None,
                lang="cn",
                verbose=True,
            ),
            confirmation_callback=lambda message: self._wait_for_approval(task, message),
            takeover_callback=lambda message: self._wait_for_takeover(task, message),
        )

        task.status = "running"
        task.updated_at = time.time()
        self._save_task(task)
        self._emit("task_started", task, {"task": task.to_dict(include_steps=False)})

        for index in range(task.max_steps):
            if task.id in self._cancel_flags or task.status == "cancelled":
                self._finish_cancelled(task)
                return

            result = agent.step(task.objective if index == 0 else None)
            observation = self._observe_current_screen(task)
            step = PhoneStep(
                task_id=task.id,
                index=index,
                thinking=result.thinking,
                action=result.action,
                observation=observation,
                success=result.success,
                finished=result.finished,
                message=result.message or "",
            )
            task.steps.append(step)
            task.updated_at = time.time()
            self._save_task(task)
            store.save_step(step)
            self._emit("task_step", task, {"step": step.to_dict(), "task": task.to_dict(include_steps=False)})
            self._emit("task_observation", task, {"observation": observation.to_dict(), "step_index": index})

            if task.id in self._cancel_flags or task.status == "cancelled":
                self._finish_cancelled(task)
                return

            if result.finished:
                if task.success_criteria:
                    task.status = "verifying"
                    task.updated_at = time.time()
                    self._save_task(task)
                    self._emit(
                        "task_verifying",
                        task,
                        {"success_criteria": task.success_criteria, "task": task.to_dict(include_steps=False)},
                    )
                task.status = "done"
                task.result = result.message or "任务完成"
                task.finished_at = time.time()
                task.updated_at = time.time()
                self._save_task(task)
                self._emit("task_done", task, {"result": task.result, "task": task.to_dict(include_steps=False)})
                return

        task.status = "done"
        task.result = f"达到最大步数 ({task.max_steps})，请由主 Agent 检查是否需要继续派发子任务"
        task.finished_at = time.time()
        task.updated_at = time.time()
        self._save_task(task)
        self._emit("task_done", task, {"result": task.result, "task": task.to_dict(include_steps=False)})

    def _wait_for_approval(self, task: PhoneTask, message: str) -> bool:
        control = _WaitControl(kind="approval", message=message)
        self._wait_controls[task.id] = control
        task.status = "waiting_approval"
        task.updated_at = time.time()
        self._save_task(task)
        self._emit("task_waiting_approval", task, {"message": message, "task": task.to_dict(include_steps=False)})
        while not control.event.wait(self.configured_poll_interval):
            if task.id in self._cancel_flags:
                return False
        self._wait_controls.pop(task.id, None)
        task.status = "running"
        task.updated_at = time.time()
        self._save_task(task)
        return control.approved

    def _wait_for_takeover(self, task: PhoneTask, message: str) -> None:
        control = _WaitControl(kind="takeover", message=message)
        self._wait_controls[task.id] = control
        task.status = "waiting_takeover"
        task.updated_at = time.time()
        self._save_task(task)
        self._emit("task_waiting_takeover", task, {"message": message, "task": task.to_dict(include_steps=False)})
        while not control.event.wait(self.configured_poll_interval):
            if task.id in self._cancel_flags:
                return
        self._wait_controls.pop(task.id, None)
        task.status = "running"
        task.updated_at = time.time()
        self._save_task(task)

    @property
    def configured_poll_interval(self) -> float:
        return max(0.05, float(settings.phone_task_poll_interval_seconds or 0.2))

    def _observe_current_screen(self, task: PhoneTask) -> PhoneObservation:
        try:
            from phone_agent.device_factory import get_device_factory

            current_app = get_device_factory().get_current_app(task.device_id or None)
        except Exception:  # noqa: BLE001
            current_app = ""
        last = task.steps[-1] if task.steps else None
        summary = ""
        if last is not None:
            summary = last.message or (last.thinking[:120] if last.thinking else "")
        return PhoneObservation(current_app=current_app, screen_summary=summary)

    def _finish_cancelled(self, task: PhoneTask) -> None:
        task.status = "cancelled"
        task.result = "用户取消"
        task.finished_at = time.time()
        task.updated_at = time.time()
        self._save_task(task)
        self._emit("task_cancelled", task, {"task": task.to_dict(include_steps=False)})

    def _save_task(self, task: PhoneTask) -> None:
        self._tasks[task.id] = task
        store.save_task(task)

    def _emit(self, event_type: str, task: PhoneTask, payload: dict[str, Any]) -> None:
        event = PhoneEvent(type=event_type, task_id=task.id, payload=payload)
        store.save_event(event)
        loop = self._loop
        if loop is None:
            return
        for queue in list(self._subscribers):
            loop.call_soon_threadsafe(queue.put_nowait, event)

    def _task_summary(self, task: PhoneTask) -> str:
        if not task.steps:
            return f"任务 {task.status}：{task.objective}"
        last = task.steps[-1]
        action = last.action.get("action") if isinstance(last.action, dict) else ""
        app = last.observation.current_app or "未知应用"
        return f"任务 {task.status}，已执行 {len(task.steps)} 步，当前应用 {app}，最近动作 {action or '暂无'}。"


_runtime: PhoneRuntime | None = None


def get_phone_runtime() -> PhoneRuntime:
    global _runtime
    if _runtime is None:
        _runtime = PhoneRuntime()
    return _runtime
