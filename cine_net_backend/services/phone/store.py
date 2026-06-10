"""Phone Runtime SQLite 存储。"""
from __future__ import annotations

import json
from typing import Any

from db import get_conn, init_db

from .models import PhoneEvent, PhoneObservation, PhoneStep, PhoneTask

_READY = False


def _ensure_db() -> None:
    global _READY
    if not _READY:
        init_db()
        _READY = True


def _json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False)


def _loads_dict(value: str | None) -> dict[str, Any]:
    if not value:
        return {}
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def save_task(task: PhoneTask) -> None:
    _ensure_db()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO phone_tasks(
                id, thread_id, parent_task_id, objective, success_criteria,
                device_type, device_id, status, result, error, max_steps,
                created_at, updated_at, finished_at
            )
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                thread_id = excluded.thread_id,
                parent_task_id = excluded.parent_task_id,
                objective = excluded.objective,
                success_criteria = excluded.success_criteria,
                device_type = excluded.device_type,
                device_id = excluded.device_id,
                status = excluded.status,
                result = excluded.result,
                error = excluded.error,
                max_steps = excluded.max_steps,
                updated_at = excluded.updated_at,
                finished_at = excluded.finished_at
            """,
            (
                task.id,
                task.thread_id,
                task.parent_task_id,
                task.objective,
                task.success_criteria,
                task.device_type,
                task.device_id,
                task.status,
                task.result,
                task.error,
                task.max_steps,
                str(task.created_at),
                str(task.updated_at),
                str(task.finished_at or ""),
            ),
        )


def save_step(step: PhoneStep) -> None:
    _ensure_db()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO phone_steps(
                id, task_id, step_index, thinking, action_json, observation_json,
                success, finished, message, created_at
            )
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                thinking = excluded.thinking,
                action_json = excluded.action_json,
                observation_json = excluded.observation_json,
                success = excluded.success,
                finished = excluded.finished,
                message = excluded.message
            """,
            (
                step.id,
                step.task_id,
                step.index,
                step.thinking,
                _json(step.action or {}),
                _json(step.observation.to_dict()),
                1 if step.success else 0,
                1 if step.finished else 0,
                step.message,
                str(step.created_at),
            ),
        )


def save_event(event: PhoneEvent) -> None:
    _ensure_db()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO phone_events(id, task_id, event_type, payload_json, created_at)
            VALUES(?, ?, ?, ?, ?)
            """,
            (event.id, event.task_id, event.type, _json(event.payload), str(event.created_at)),
        )


def _task_from_row(row, *, steps: list[PhoneStep] | None = None) -> PhoneTask:
    finished_raw = str(row["finished_at"] or "")
    task = PhoneTask(
        id=row["id"],
        thread_id=row["thread_id"] or "",
        parent_task_id=row["parent_task_id"] or "",
        objective=row["objective"] or "",
        success_criteria=row["success_criteria"] or "",
        device_type=(row["device_type"] or "adb"),
        device_id=row["device_id"] or "",
        status=row["status"] or "queued",
        result=row["result"] or "",
        error=row["error"] or "",
        max_steps=int(row["max_steps"] or 30),
        created_at=float(row["created_at"] or 0),
        updated_at=float(row["updated_at"] or 0),
        finished_at=float(finished_raw) if finished_raw else None,
    )
    task.steps = steps or []
    return task


def _step_from_row(row) -> PhoneStep:
    return PhoneStep(
        task_id=row["task_id"],
        index=int(row["step_index"]),
        thinking=row["thinking"] or "",
        action=_loads_dict(row["action_json"]) or None,
        observation=PhoneObservation.from_dict(_loads_dict(row["observation_json"])),
        success=bool(row["success"]),
        finished=bool(row["finished"]),
        message=row["message"] or "",
        created_at=float(row["created_at"] or 0),
    )


def get_task(task_id: str, *, include_steps: bool = True) -> PhoneTask | None:
    _ensure_db()
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM phone_tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            return None
        steps = []
        if include_steps:
            step_rows = conn.execute(
                "SELECT * FROM phone_steps WHERE task_id = ? ORDER BY step_index ASC",
                (task_id,),
            ).fetchall()
            steps = [_step_from_row(step_row) for step_row in step_rows]
    return _task_from_row(row, steps=steps)


def list_tasks(status: str | None = None, limit: int = 50) -> list[PhoneTask]:
    _ensure_db()
    with get_conn() as conn:
        if status:
            rows = conn.execute(
                "SELECT * FROM phone_tasks WHERE status = ? ORDER BY updated_at DESC LIMIT ?",
                (status, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM phone_tasks ORDER BY updated_at DESC LIMIT ?",
                (limit,),
            ).fetchall()
    return [_task_from_row(row, steps=[]) for row in rows]


def list_events(task_id: str | None = None, limit: int = 200) -> list[PhoneEvent]:
    _ensure_db()
    with get_conn() as conn:
        if task_id:
            rows = conn.execute(
                "SELECT * FROM phone_events WHERE task_id = ? ORDER BY created_at ASC LIMIT ?",
                (task_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM phone_events ORDER BY created_at DESC LIMIT ?",
                (limit,),
            ).fetchall()
    return [
        PhoneEvent(
            id=row["id"],
            task_id=row["task_id"],
            type=row["event_type"],
            payload=_loads_dict(row["payload_json"]),
            created_at=float(row["created_at"] or 0),
        )
        for row in rows
    ]
