from unittest import TestCase

from services.catalog.models import CatalogMovie
from services.microdesign import (
    compose_catalog_post,
    compose_media_gallery,
    compose_movie_carousel,
    compose_poster,
    compose_recommendation_posts,
    compose_review_quote_card,
    compose_source_trace_card,
)
from services.resources.models import (
    AggregatedMediaItem,
    Episode,
    MediaResourceDetail,
    PlayLine,
    ResourceCandidate,
    ResourceSearchResponse,
)


class MicroDesignTests(TestCase):
    def setUp(self) -> None:
        self.candidate = ResourceCandidate(
            provider_id="demo",
            provider_name="演示源",
            remote_id="42",
            title="星际穿越",
            category="科幻片",
            cover_url="https://img.example/interstellar.jpg",
            remarks="1080P",
            year="2014",
        )

    def test_compose_feed_post(self) -> None:
        response = ResourceSearchResponse(
            keyword="星际穿越",
            items=[
                AggregatedMediaItem(
                    normalized_title="星际穿越",
                    title="星际穿越",
                    category="科幻片",
                    cover_url=self.candidate.cover_url,
                    sources=[self.candidate],
                )
            ],
        )

        post = compose_recommendation_posts(response)[0]

        self.assertTrue(post.has_video_source)
        self.assertEqual("posterRow", post.blocks[0].type)
        self.assertEqual("microdesign.v1.1", post.schema_version)
        self.assertEqual(["openResourcePoster", "resolveAndPlay"], [action.type for action in post.actions])

    def test_creative_cards_match_flutter_v11_fields(self) -> None:
        movie = CatalogMovie(
            catalog_id="douban:1889243",
            provider_id="douban",
            provider_name="豆瓣",
            source_id="1889243",
            title="星际穿越",
            year="2014",
            media_kind="movie",
            rating=9.4,
            poster_url="https://img.example/poster.jpg",
            overview="一群探索者穿越虫洞寻找新家园。",
            genres=["科幻", "冒险", "剧情"],
        )
        resource = AggregatedMediaItem(
            normalized_title="星际穿越",
            title="星际穿越",
            category="科幻片",
            year="2014",
            sources=[self.candidate],
        )

        post = compose_catalog_post(movie, resource)
        card = post.blocks[0]
        carousel = compose_movie_carousel([post])
        quote = compose_review_quote_card(post)
        trace = compose_source_trace_card(query="星际穿越", catalog_ok=2, catalog_failed=0, resource_count=1)
        gallery = compose_media_gallery(["https://img.example/a.jpg"])

        self.assertEqual("playableMovieCard", card.type)
        for key in ("cover", "title", "year", "rating", "rating_label", "summary", "genres", "source_count", "actions"):
            self.assertIn(key, card.data)
        self.assertEqual(["resolveAndPlay", "openPoster"], [action["type"] for action in card.data["actions"]])
        self.assertEqual("https://img.example/poster.jpg", carousel.data["items"][0]["cover"])
        self.assertEqual("openPoster", carousel.data["items"][0]["action"]["type"])
        self.assertIn("source", quote.data)
        self.assertEqual("星际穿越", trace.data["query"])
        self.assertIn(trace.data["items"][0]["status"], {"ok", "empty"})
        self.assertEqual(["https://img.example/a.jpg"], gallery.data["urls"])

    def test_compose_dynamic_poster(self) -> None:
        detail = MediaResourceDetail(
            **self.candidate.model_dump(),
            summary="穿越星际寻找新的家园。",
            play_lines=[PlayLine(name="m3u8", episodes=[Episode(name="正片", play_url="https://cdn.example/a.m3u8")])],
        )

        poster = compose_poster(detail)

        self.assertEqual("neon", poster.style)
        self.assertEqual("banner", poster.blocks[0].type)
        self.assertEqual("videoBar", poster.blocks[-1].type)
        self.assertEqual("https://cdn.example/a.m3u8", poster.blocks[-1].data["play_url"])
        self.assertEqual("resolveAndPlay", poster.blocks[-1].action.type)
        self.assertEqual("https://cdn.example/a.m3u8", poster.blocks[-1].action.data["play_url"])
