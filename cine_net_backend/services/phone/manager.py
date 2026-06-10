"""兼容层：旧代码的 PhoneTaskManager 名称指向新的 PhoneRuntime。"""
from __future__ import annotations

from .runtime import PhoneRuntime, get_phone_runtime

PhoneTaskManager = PhoneRuntime


def get_phone_manager() -> PhoneRuntime:
    return get_phone_runtime()
