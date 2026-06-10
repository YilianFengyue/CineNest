"""手机自动化任务模型。

Phone Runtime 是主 Agent 调度 AutoGLM 子 Agent 的稳定边界：
任务可持久化、可订阅事件、可人工确认/接管，也可被主 Agent 再次检查。
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any, Literal
from uuid import uuid4


PhoneTaskStatus = Literal[
    "queued",
    "running",
    "waiting_approval",
    "waiting_takeover",
    "verifying",
    "done",
    "failed",
    "cancelled",
]

PhoneDeviceType = Literal["adb", "hdc"]

PhoneEventType = Literal[
    "task_created",
    "task_started",
    "task_step",
    "task_observation",
    "task_waiting_approval",
    "task_waiting_takeover",
    "task_verifying",
    "task_done",
    "task_failed",
    "task_cancelled",
    "task_instruction",
]


def _task_id() -> str:
    return f"phone-{uuid4().hex[:12]}"


def _event_id() -> str:
    return f"pe-{uuid4().hex[:16]}"


def _step_id(task_id: str, index: int) -> str:
    return f"{task_id}-step-{index}"


@dataclass
class PhoneObservation:
    current_app: str = ""
    screen_summary: str = ""
    screenshot_asset_id: str = ""
    raw: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "current_app": self.current_app,
            "screen_summary": self.screen_summary,
            "screenshot_asset_id": self.screenshot_asset_id,
            "raw": self.raw,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "PhoneObservation":
        data = data or {}
        return cls(
            current_app=str(data.get("current_app") or ""),
            screen_summary=str(data.get("screen_summary") or ""),
            screenshot_asset_id=str(data.get("screenshot_asset_id") or ""),
            raw=dict(data.get("raw") or {}),
        )


@dataclass
class PhoneStep:
    task_id: str
    index: int
    thinking: str = ""
    action: dict[str, Any] | None = None
    observation: PhoneObservation = field(default_factory=PhoneObservation)
    success: bool = False
    finished: bool = False
    message: str = ""
    created_at: float = field(default_factory=time.time)

    @property
    def id(self) -> str:
        return _step_id(self.task_id, self.index)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "task_id": self.task_id,
            "index": self.index,
            "thinking": self.thinking,
            "action": self.action,
            "observation": self.observation.to_dict(),
            "success": self.success,
            "finished": self.finished,
            "message": self.message,
            "created_at": self.created_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "PhoneStep":
        return cls(
            task_id=str(data.get("task_id") or ""),
            index=int(data.get("index") or 0),
            thinking=str(data.get("thinking") or ""),
            action=dict(data.get("action") or {}) or None,
            observation=PhoneObservation.from_dict(data.get("observation")),
            success=bool(data.get("success")),
            finished=bool(data.get("finished")),
            message=str(data.get("message") or ""),
            created_at=float(data.get("created_at") or time.time()),
        )


@dataclass
class PhoneTask:
    objective: str
    id: str = field(default_factory=_task_id)
    thread_id: str = ""
    parent_task_id: str = ""
    success_criteria: str = ""
    device_type: PhoneDeviceType = "adb"
    device_id: str = ""
    status: PhoneTaskStatus = "queued"
    steps: list[PhoneStep] = field(default_factory=list)
    result: str = ""
    error: str = ""
    max_steps: int = 30
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    finished_at: float | None = None

    def to_dict(self, *, include_steps: bool = True) -> dict[str, Any]:
        return {
            "task_id": self.id,
            "id": self.id,
            "thread_id": self.thread_id,
            "parent_task_id": self.parent_task_id,
            "objective": self.objective,
            "description": self.objective,
            "success_criteria": self.success_criteria,
            "device_type": self.device_type,
            "device_id": self.device_id,
            "status": self.status,
            "step_count": len(self.steps),
            "current_step": self.steps[-1].to_dict() if self.steps else None,
            "steps": [step.to_dict() for step in self.steps] if include_steps else [],
            "result": self.result,
            "error": self.error,
            "max_steps": self.max_steps,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "finished_at": self.finished_at,
            "schema_version": "phone_task.v2",
        }


@dataclass
class PhoneEvent:
    type: PhoneEventType
    task_id: str
    payload: dict[str, Any] = field(default_factory=dict)
    id: str = field(default_factory=_event_id)
    created_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "type": self.type,
            "task_id": self.task_id,
            "payload": self.payload,
            "created_at": self.created_at,
            "schema_version": "phone_event.v1",
        }
