from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from services.bili.cache import clear_cache
from services.bili.normalizer import clean_html_text, fix_url, with_video_extras
from services.bili.service import get_movie_videos


RAW_VIDEO = {
    "type": "video",
    "id": 115552504782555,
    "author": "Ms混剪-",
    "mid": 3546673265511279,
    "arcurl": "http://www.bilibili.com/video/av115552504782555",
    "aid": 115552504782555,
    "bvid": "BV1ysCCBTEVC",
    "title": "用万字解读<em class=\"keyword\">电影</em>《<em class=\"keyword\">你的名字</em>》",
    "description": "用万字解读电影《你的名字》",
    "pic": "//i2.hdslb.com/bfs/archive/demo.jpg",
    "play": 23808,
    "video_review": 35,
    "favorites": 488,
    "tag": "你的名字,生死,爱情,动漫,电影解说,电影",
    "pubdate": 1763191644,
    "duration": "22:14",
    "like": 715,
    "danmaku": 35,
}


class BiliNormalizerTests(TestCase):
    def test_video_extras_keep_raw_fields_and_add_app_jump(self) -> None:
        item = with_video_extras(RAW_VIDEO)

        self.assertEqual(RAW_VIDEO["title"], item["title"])
        self.assertEqual("用万字解读电影《你的名字》", item["_cinenest"]["title_plain"])
        self.assertEqual("https://i2.hdslb.com/bfs/archive/demo.jpg", item["_cinenest"]["cover_url"])
        self.assertEqual("https://www.bilibili.com/video/BV1ysCCBTEVC", item["_cinenest"]["web_url"])
        self.assertEqual("bilibili://video/BV1ysCCBTEVC", item["_cinenest"]["app_url"])

    def test_clean_and_fix_url(self) -> None:
        self.assertEqual("电影《你的名字》", clean_html_text("<em>电影</em>《你的名字》"))
        self.assertEqual("https://i0.hdslb.com/x.jpg", fix_url("//i0.hdslb.com/x.jpg"))


class BiliServiceTests(IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        clear_cache()

    async def test_movie_videos_keeps_raw_shape_and_paginates(self) -> None:
        async def fake_search(keyword: str, order: str = "total", page: int = 1, page_size: int = 12):
            from services.bili.models import BiliEnvelope

            item = dict(RAW_VIDEO)
            item["bvid"] = f"BV{abs(hash(keyword)) % 100000}"
            return BiliEnvelope(
                result_type="video",
                keyword=keyword,
                page=page,
                page_size=page_size,
                count=1,
                data=[with_video_extras(item)],
            )

        with patch("services.bili.service.search_videos", new=AsyncMock(side_effect=fake_search)):
            envelope = await get_movie_videos("你的名字", page=1, page_size=3)

        self.assertEqual("bili.raw.v1", envelope.schema_version)
        self.assertEqual("你的名字", envelope.movie)
        self.assertEqual(3, envelope.count)
        self.assertIn("title", envelope.data[0])
        self.assertIn("_cinenest", envelope.data[0])
        self.assertTrue(envelope.extra["has_more"])


class BiliApiTests(TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_movie_videos_endpoint_uses_raw_envelope(self) -> None:
        from services.bili.models import BiliEnvelope

        envelope = BiliEnvelope(
            result_type="video",
            movie="你的名字",
            page=1,
            page_size=1,
            count=1,
            data=[with_video_extras(RAW_VIDEO)],
            extra={"cached": False, "has_more": False},
        )
        with patch("routers.bili.get_movie_videos", new=AsyncMock(return_value=envelope)):
            response = self.client.get("/api/bili/movie/videos", params={"movie": "你的名字", "page_size": 1})

        self.assertEqual(200, response.status_code)
        payload = response.json()
        self.assertEqual("video", payload["result_type"])
        self.assertEqual(RAW_VIDEO["title"], payload["data"][0]["title"])
        self.assertEqual("bilibili://video/BV1ysCCBTEVC", payload["data"][0]["_cinenest"]["app_url"])
