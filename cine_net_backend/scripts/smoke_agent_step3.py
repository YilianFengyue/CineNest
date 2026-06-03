"""Step 3 Agent smoke：功夫熊猫 Tool 调度与结构化附件。"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.agent import AgentServiceUnavailableError, invoke_agent
from services.llm import is_llm_configured


def _utf8_console() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


async def main() -> None:
    _utf8_console()
    if not is_llm_configured():
        raise SystemExit("请先在 .env 填写 LLM_API_KEY / LLM_BASE_URL / LLM_MODEL")
    keyword = sys.argv[1] if len(sys.argv) > 1 else "功夫熊猫"
    thread_id = f"smoke-step3-feed-{uuid4().hex[:8]}"
    try:
        result = await invoke_agent(
            f"请调用 build_recommendation_feed 工具，为“{keyword}”生成最多 2 个真实可播放推荐帖子。"
            "资料字段缺失时只说暂无，不要凭记忆补充。",
            thread_id,
        )
    except AgentServiceUnavailableError as exc:
        raise SystemExit(str(exc)) from exc
    print(result.model_dump_json(indent=2))
    tools = {call.get("name") for call in result.tool_calls}
    if "build_recommendation_feed" not in tools:
        raise SystemExit(f"模型未调用 build_recommendation_feed，实际调用: {sorted(tools)}")
    if not result.attachments or result.attachments[0].type != "recommendation_feed":
        raise SystemExit("Agent 没有返回 recommendation_feed 结构化附件")
    posts = result.attachments[0].payload.get("posts") or []
    if not posts or not posts[0].get("actions"):
        raise SystemExit("Agent 附件中没有可交互帖子 Action")
    print("\nStep 3 Agent smoke 通过")


if __name__ == "__main__":
    asyncio.run(main())
