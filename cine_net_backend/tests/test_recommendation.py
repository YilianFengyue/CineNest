from unittest import IsolatedAsyncioTestCase

from services.catalog.models import CatalogMovie, CatalogSearchResponse
from services.recommendation.service import RecommendationService
from services.resources.models import (
    AggregatedMediaItem,
    MediaResourceDetail,
    PlayLine,
    Episode,
    ResourceCandidate,
    ResourceSearchResponse,
)


class _FakeCatalog:
    async def search(self, query: str, *, media_kind: str, limit: int):
        return CatalogSearchResponse(
            query=query,
            items=[
                CatalogMovie(
                    catalog_id="douban:1889243",
                    provider_id="douban",
                    provider_name="豆瓣",
                    source_id="1889243",
                    title="星际穿越",
                    year="2014",
                    media_kind="movie",
                    rating=9.4,
                    poster_url="https://img.example/douban.jpg",
                    overview="穿越星际寻找新的家园。",
                    genres=["科幻", "冒险"],
                )
            ],
        )

    async def hot(self, *, media_kind: str, limit: int):
        return await self.search("热门", media_kind=media_kind, limit=limit)

    async def detail(self, provider_id: str, source_id: str, *, media_kind: str):
        return (await self.search("星际穿越", media_kind=media_kind, limit=1)).items[0]


class _FakeResources:
    def __init__(self) -> None:
        self.search_count = 0
        self.candidate = ResourceCandidate(
            provider_id="wujin",
            provider_name="无尽资源",
            remote_id="93364",
            title="星际穿越",
            category="科幻片",
            cover_url="https://img.example/maccms.jpg",
            remarks="HD中字",
            year="2014",
        )

    async def search(self, keyword: str):
        self.search_count += 1
        return ResourceSearchResponse(
            keyword=keyword,
            items=[
                AggregatedMediaItem(
                    normalized_title="星际穿越",
                    title="星际穿越",
                    category="科幻片",
                    remarks="HD中字",
                    year="2014",
                    sources=[self.candidate],
                )
            ],
        )

    async def detail(self, provider_id: str, remote_id: str):
        return MediaResourceDetail(
            **self.candidate.model_dump(),
            summary="资源简介",
            play_lines=[
                PlayLine(name="m3u8", episodes=[Episode(name="HD中字", play_url="https://cdn.example/movie.m3u8")])
            ],
        )


class RecommendationTests(IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.service = RecommendationService(persist=False)
        self.service.catalog = _FakeCatalog()
        self.service.resources = _FakeResources()

    async def test_recommendation_combines_catalog_and_resources(self) -> None:
        feed = await self.service.recommend(query="科幻", limit=3)

        post = feed.posts[0]
        self.assertEqual("douban:1889243", post.catalog_id)
        self.assertEqual(9.4, post.rating)
        self.assertEqual("https://img.example/douban.jpg", post.cover_url)
        self.assertTrue(post.has_video_source)
        self.assertEqual(["openPoster", "resolveAndPlay"], [action.type for action in post.actions])
        self.assertEqual("douban", post.actions[0].data["catalog_provider_id"])

    async def test_catalog_poster_contains_rating_reason_and_play_line(self) -> None:
        poster = await self.service.poster("douban", "1889243")

        self.assertEqual("douban:1889243", poster.catalog_id)
        self.assertEqual(["banner", "rating", "tagRow"], [block.type for block in poster.blocks[:3]])
        self.assertEqual("videoBar", poster.blocks[-1].type)
        self.assertEqual("resolveAndPlay", poster.blocks[-1].action.type)

    async def test_recommendation_feed_uses_short_cache(self) -> None:
        await self.service.recommend(query="科幻", limit=3)
        await self.service.recommend(query="科幻", limit=3)

        self.assertEqual(1, self.service.resources.search_count)
