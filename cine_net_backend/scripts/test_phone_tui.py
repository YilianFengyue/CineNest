#!/usr/bin/env python3
"""AutoGLM 手机控制 TUI — 全链路测试。

两种模式：
  1. --direct    直接调用 AutoGLM（跳过主 Agent，测裸链路）
  2. 默认        模拟完整链路：主 Agent 判断意图 → 调 execute_phone_task → 异步追踪

用法：
    cd cine_net_backend
    set PYTHONIOENCODING=utf-8

    # 全链路（主 Agent → AutoGLM，需要 LangChain）
    python scripts/test_phone_tui.py

    # 直接测 AutoGLM（不需要 LangChain）
    python scripts/test_phone_tui.py --direct
    python scripts/test_phone_tui.py --direct --task "打开哔哩哔哩搜索流浪地球"
    python scripts/test_phone_tui.py --direct --step
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))


SEP = "=" * 60
THIN = "─" * 60


def _print_header(text: str) -> None:
    print(f"\n{SEP}\n  {text}\n{SEP}")


def _print_step(step_data: dict) -> None:
    idx = step_data.get("index", "?")
    print(f"\n{THIN}")
    print(f"  Step {int(idx) + 1}")
    print(THIN)

    thinking = step_data.get("thinking", "")
    if thinking:
        lines = thinking.strip().split("\n")
        preview = lines[0][:120]
        if len(lines) > 1 or len(lines[0]) > 120:
            preview += " ..."
        print(f"  Thinking: {preview}")

    action = step_data.get("action")
    if action:
        print(f"  Action:   {json.dumps(action, ensure_ascii=False)}")

    status = "OK" if step_data.get("success") else "FAIL"
    if step_data.get("finished"):
        status += " [FINISHED]"
    print(f"  Status:   {status}")

    msg = step_data.get("message")
    if msg:
        print(f"  Message:  {msg}")


# ─── 模式 1: 直接调 AutoGLM ───────────────────────────────

def run_direct(config: dict, task: str, step_mode: bool = False) -> None:
    """直接调用 PhoneAgent，不经过主 Agent。"""
    from phone_agent import PhoneAgent
    from phone_agent.agent import AgentConfig
    from phone_agent.model import ModelConfig

    agent = PhoneAgent(
        model_config=ModelConfig(
            base_url=config["base_url"],
            api_key=config["api_key"],
            model_name=config["model"],
        ),
        agent_config=AgentConfig(
            max_steps=config["max_steps"],
            device_id=config["device_id"],
            lang="cn",
            verbose=True,
        ),
        confirmation_callback=lambda msg: (print(f"\n  [?] 确认: {msg}"), True)[1],
        takeover_callback=lambda msg: input(f"\n  [!] 人工接管: {msg}\n  完成后按 Enter..."),
    )

    _print_header(f"[Direct] {task}")
    t0 = time.time()
    result = agent.step(task)
    _print_step({"index": 0, "thinking": result.thinking, "action": result.action,
                 "success": result.success, "finished": result.finished, "message": result.message})

    idx = 1
    while not result.finished and idx < config["max_steps"]:
        if step_mode:
            r = input("\n  [Enter] 继续 / [q] 退出: ").strip()
            if r == "q":
                break
        result = agent.step()
        _print_step({"index": idx, "thinking": result.thinking, "action": result.action,
                     "success": result.success, "finished": result.finished, "message": result.message})
        idx += 1

    print(f"\n  Done in {time.time() - t0:.1f}s, {idx} steps. Result: {result.message or 'N/A'}")


# ─── 模式 2: 全链路（主 Agent → execute_phone_task → 异步追踪）─

async def run_agent_chain(task: str) -> None:
    """模拟完整链路：用户消息 → 主 Agent 判断 → 调 phone tool → 异步追踪步骤。"""
    from services.phone import get_phone_manager

    manager = get_phone_manager()

    _print_header(f"[Agent Chain] 用户: {task}")

    # 订阅事件
    queue = manager.subscribe()

    # 尝试走主 Agent（需要 LangChain）
    agent_reply = None
    try:
        from services.agent import invoke_agent
        print("\n  >>> 主 Agent 处理中...")
        result = await invoke_agent(task, thread_id="tui-test")
        agent_reply = result.answer
        print(f"\n  Agent 回复: {agent_reply}")

        phone_triggered = any(
            att.type == "phone_task" for att in result.attachments
        )
        if not phone_triggered:
            print("  (Agent 未触发手机操作)")
            manager.unsubscribe(queue)
            return
    except ImportError:
        print("\n  [!] LangChain 未安装，直接启动 phone task...")
        await manager.start_task(task)
    except Exception as exc:
        print(f"\n  [!] Agent 调用失败 ({exc})，直接启动 phone task...")
        await manager.start_task(task)

    # 实时追踪 phone 步骤
    print(f"\n  >>> 手机操作进行中，实时追踪...")
    try:
        async for event in manager.iter_events(queue):
            if event.type == "phone_step" and event.step:
                _print_step(event.step.to_dict())
            elif event.type == "phone_done":
                print(f"\n  [DONE] {event.task.result}")
            elif event.type == "phone_error":
                print(f"\n  [ERROR] {event.task.error}")
    finally:
        manager.unsubscribe(queue)


def interactive_agent() -> None:
    """交互模式：循环接受任务，走全链路。"""
    print("\n输入消息（如 '帮我在B站搜流浪地球解说'），输入 q 退出。\n")
    loop = asyncio.new_event_loop()
    while True:
        try:
            msg = input("You> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not msg or msg.lower() == "q":
            break
        try:
            loop.run_until_complete(run_agent_chain(msg))
        except KeyboardInterrupt:
            print("\n  任务被中断。")
        except Exception as exc:
            print(f"\n  [ERROR] {exc}")
            import traceback
            traceback.print_exc()
        print()
    loop.close()


# ─── 通用 ────────────────────────────────────────────────

def check_adb() -> bool:
    try:
        from phone_agent.adb.connection import ADBConnection
    except ImportError:
        print("[!] phone_agent 未安装。请执行:")
        print("    python -m pip install -e ../CodeReference/Open-AutoGLM")
        return False
    try:
        conn = ADBConnection()
        devices = conn.list_devices()
        if not devices:
            print("[!] 没有检测到 ADB 设备。请检查 USB 连接和 USB 调试。")
            return False
        print(f"[OK] 检测到 {len(devices)} 台设备:")
        for d in devices:
            print(f"     - {d.device_id} ({d.status})")
        return True
    except Exception as exc:
        print(f"[!] ADB 检查失败: {exc}")
        return False


def load_config() -> dict:
    cfg = {
        "base_url": os.getenv("PHONE_MODEL_BASE_URL", "https://open.bigmodel.cn/api/paas/v4"),
        "api_key": os.getenv("PHONE_API_KEY", ""),
        "model": os.getenv("PHONE_MODEL_NAME", "autoglm-phone"),
        "device_id": os.getenv("PHONE_DEVICE_ID", "") or None,
        "max_steps": int(os.getenv("PHONE_MAX_STEPS", "30")),
    }
    print(f"  Model:     {cfg['model']}")
    print(f"  Base URL:  {cfg['base_url']}")
    key = cfg["api_key"]
    print(f"  API Key:   {'***' + key[-6:] if len(key) > 6 else '(未设置)'}")
    print(f"  Device:    {cfg['device_id'] or '(自动检测)'}")
    print(f"  Max Steps: {cfg['max_steps']}")
    return cfg


def main() -> None:
    parser = argparse.ArgumentParser(description="AutoGLM 手机控制 TUI — 全链路测试")
    parser.add_argument("--direct", action="store_true", help="直接调用 AutoGLM（跳过主 Agent）")
    parser.add_argument("--task", type=str, help="直接执行指定任务")
    parser.add_argument("--step", action="store_true", help="[direct模式] 单步确认")
    parser.add_argument("--skip-adb-check", action="store_true", help="跳过 ADB 检查")
    args = parser.parse_args()

    _print_header("CineNest Phone Agent TUI")

    print("\n[1] 配置:")
    config = load_config()
    if not config["api_key"]:
        print("\n请在 .env 中设置 PHONE_API_KEY")
        sys.exit(1)

    if not args.skip_adb_check:
        print("\n[2] ADB:")
        if not check_adb():
            sys.exit(1)

    mode = "direct" if args.direct else "agent-chain"
    print(f"\n[3] 模式: {mode}")

    if args.direct:
        if args.task:
            run_direct(config, args.task, args.step)
        else:
            print("\n输入任务（如 '打开哔哩哔哩搜索流浪地球'），输入 q 退出。\n")
            while True:
                try:
                    t = input("Task> ").strip()
                except (EOFError, KeyboardInterrupt):
                    break
                if not t or t.lower() == "q":
                    break
                try:
                    run_direct(config, t, args.step)
                except KeyboardInterrupt:
                    print("\n  中断。")
                except Exception as e:
                    print(f"\n  [ERROR] {e}")
                print()
    else:
        if args.task:
            asyncio.run(run_agent_chain(args.task))
        else:
            interactive_agent()

    print("\nBye!")


if __name__ == "__main__":
    main()
