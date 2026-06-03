from __future__ import annotations

import datetime
import json
from pathlib import Path
from typing import Any

from models.schemas import UserPreference

STATE_PATH = Path(__file__).resolve().parent / "cinenest_state.json"


def _empty_preference() -> UserPreference:
    return UserPreference(liked_genres=[], disliked_genres=[], free_text="")


def _default_state() -> dict[str, Any]:
    return {
        "preferences": _empty_preference().model_dump(),
        "watch_history": [],
    }


def _read_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return _default_state()
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return _default_state()
    if not isinstance(data, dict):
        return _default_state()
    data.setdefault("preferences", _empty_preference().model_dump())
    data.setdefault("watch_history", [])
    return data


def _write_state(state: dict[str, Any]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(
        json.dumps(state, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def init_db() -> None:
    if not STATE_PATH.exists():
        _write_state(_default_state())


def save_user_preference(pref: UserPreference) -> None:
    state = _read_state()
    state["preferences"] = pref.model_dump()
    _write_state(state)


def get_user_preference() -> UserPreference:
    state = _read_state()
    pref_data = state.get("preferences") or {}
    if not isinstance(pref_data, dict):
        return _empty_preference()
    return UserPreference(
        liked_genres=list(pref_data.get("liked_genres") or []),
        disliked_genres=list(pref_data.get("disliked_genres") or []),
        free_text=pref_data.get("free_text") or "",
    )


def add_watch_history(movie_id: int, title: str) -> None:
    state = _read_state()
    history = state.get("watch_history")
    if not isinstance(history, list):
        history = []

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    history = [
        item
        for item in history
        if not isinstance(item, dict) or item.get("movie_id") != movie_id
    ]
    history.insert(
        0,
        {
            "movie_id": movie_id,
            "title": title,
            "visited_at": now_str,
        },
    )
    state["watch_history"] = history[:50]
    _write_state(state)


def get_watch_history_titles() -> list[str]:
    state = _read_state()
    history = state.get("watch_history")
    if not isinstance(history, list):
        return []
    return [
        item.get("title", "")
        for item in history[:10]
        if isinstance(item, dict) and item.get("title")
    ]
