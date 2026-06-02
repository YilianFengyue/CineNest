import json
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import patch

from services.tools import get_agent_tools
from services.tools.media import build_microdesign_posts, get_playable_resource_detail, search_playable_resources
from services.resources.models import (
    AggregatedMediaItem,
    Episode,
    MediaResourceDetail,
    PlayLine,
    ProviderSearchTrace,
    ResourceCandidate,
    ResourceSearchResponse,
)


class ToolRegistryTests(TestCase):
    def test_resource_tools_are_registered(self) -> None:
        names = {tool.name for tool in get_agent_tools()}

        self.assertEqual(
            {
                "browse_catalog_hot",
                "build_catalog_microdesign_poster",
                "build_recommendation_feed",
                "get_backend_status",
                "search_playable_resources",
                "search_catalog_movies",
                "get_playable_resource_detail",
                "build_microdesign_posts",
            },
            names,
        )


class _FakeAggregator:
    def __init__(self) -> None:
        self.candidate = ResourceCandidate(
            provider_id="demo",
            provider_name="演示源",
            remote_id="42",
            title="星际穿越",
            category="科幻片",
            cover_url="https://img.example/interstellar.jpg",
            remarks="HD中字",
            year="2014",
        )

    async def search(self, keyword: str):
        return ResourceSearchResponse(
            keyword=keyword,
            items=[
                AggregatedMediaItem(
                    normalized_title="星际穿越",
                    title="星际穿越",
                    category="科幻片",
                    cover_url=self.candidate.cover_url,
                    remarks=self.candidate.remarks,
                    year=self.candidate.year,
                    sources=[self.candidate],
                )
            ],
            traces=[
                ProviderSearchTrace(
                    provider_id="demo",
                    provider_name="演示源",
                    ok=True,
                    elapsed_ms=1,
                    result_count=1,
                )
            ],
        )

    async def detail(self, provider_id: str, remote_id: str):
        return MediaResourceDetail(
            **self.candidate.model_dump(),
            summary="穿越星际寻找新的家园。",
            play_lines=[
                PlayLine(name="m3u8", episodes=[Episode(name="HD中字", play_url="https://cdn.example/movie.m3u8")])
            ],
        )


class MediaToolTests(IsolatedAsyncioTestCase):
    async def test_search_tool_returns_real_provider_shape(self) -> None:
        with patch("services.tools.media.get_resource_aggregator", return_value=_FakeAggregator()):
            payload = json.loads(await search_playable_resources.ainvoke({"keyword": "星际穿越", "limit": 3}))

        self.assertEqual("星际穿越", payload["items"][0]["title"])
        self.assertEqual("demo", payload["items"][0]["sources"][0]["provider_id"])

    async def test_detail_tool_returns_play_url(self) -> None:
        with patch("services.tools.media.get_resource_aggregator", return_value=_FakeAggregator()):
            payload = json.loads(await get_playable_resource_detail.ainvoke({"provider_id": "demo", "remote_id": "42"}))

        self.assertEqual("https://cdn.example/movie.m3u8", payload["play_lines"][0]["episodes"][0]["play_url"])

    async def test_microdesign_tool_returns_renderable_blocks(self) -> None:
        with patch("services.tools.media.get_resource_aggregator", return_value=_FakeAggregator()):
            payload = json.loads(await build_microdesign_posts.ainvoke({"keyword": "星际穿越", "limit": 3}))

        self.assertEqual("posterRow", payload[0]["blocks"][0]["type"])
