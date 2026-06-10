"""Step 2 Agent smoke：验证模型可自主调度 Catalog 与推荐 Tool。"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.agent import invoke_agent
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

    print("[1/2] Catalog 资料检索 Tool")
    catalog = await invoke_agent(
        "请调用 search_catalog_movies 工具查询电影“星际穿越”，告诉我它的评分、封面和简介。",
        "smoke-step2-catalog",
    )
    print(catalog.model_dump_json(indent=2))
    catalog_tools = {call.get("name") for call in catalog.tool_calls}
    if "search_catalog_movies" not in catalog_tools:
        raise SystemExit(f"模型未调用 search_catalog_movies，实际调用: {sorted(catalog_tools)}")

    print("\n[2/2] 可播放推荐帖子 Tool")
    feed = await invoke_agent(
        "请调用 build_recommendation_feed 工具，为“星际穿越”生成最多 2 个真实可播放推荐帖子。",
        "smoke-step2-feed",
    )
    print(feed.model_dump_json(indent=2))
    feed_tools = {call.get("name") for call in feed.tool_calls}
    if "build_recommendation_feed" not in feed_tools:
        raise SystemExit(f"模型未调用 build_recommendation_feed，实际调用: {sorted(feed_tools)}")

    print("\nStep 2 Agent smoke 通过")


if __name__ == "__main__":
    asyncio.run(main())
