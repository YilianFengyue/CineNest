"""真实聚合站 smoke：填好 .env 后验证文本与 Tool Calling。"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.agent import invoke_agent
from services.llm import is_llm_configured


async def main() -> None:
    if not is_llm_configured():
        raise SystemExit("请先复制 .env.example 为 .env，并填写 LLM_API_KEY / LLM_BASE_URL / LLM_MODEL")

    print("[1/2] 基础文本 + 系统工具调用")
    status = await invoke_agent("请调用工具查看 CineNest 后端能力，然后简短汇报。", "smoke-status")
    print(status.model_dump_json(indent=2))

    print("\n[2/2] 多源影视资源工具调用")
    search = await invoke_agent("请检索星际穿越的真实可播放资源，列出最多 3 个资源站。", "smoke-search")
    print(search.model_dump_json(indent=2))

    if not search.tool_calls:
        raise SystemExit("模型没有产生 tool_calls：请确认聚合站模型支持 OpenAI tools/function calling")
    print("\nLLM smoke 通过")


if __name__ == "__main__":
    asyncio.run(main())
