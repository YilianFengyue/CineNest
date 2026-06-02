from unittest import TestCase

from services.microdesign import compose_poster, compose_recommendation_posts
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
