from unittest import IsolatedAsyncioTestCase

from services.resources.models import ProviderConfig
from services.resources.provider import MacCMSProvider


class _StubProvider(MacCMSProvider):
    async def _get(self, params):
        if params.get("wd"):
            return {
                "list": [
                    {
                        "vod_id": 42,
                        "vod_name": "星际穿越",
                        "type_name": "科幻片",
                        "vod_pic": "https://img.example/interstellar.jpg",
                        "vod_remarks": "HD中字",
                    }
                ]
            }
        return {
            "list": [
                {
                    "vod_id": 42,
                    "vod_name": "星际穿越",
                    "type_name": "科幻片",
                    "vod_content": "<p> 穿越星际寻找新的家园。 </p>",
                    "vod_play_from": "m3u8",
                    "vod_play_url": "HD中字$https://cdn.example/movie.m3u8",
                }
            ]
        }


class MacCMSProviderTests(IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.provider = _StubProvider(
            ProviderConfig(id="demo", name="演示源", endpoint="https://api.example/vod"),
            timeout_seconds=1,
        )

    async def test_search_maps_maccms_fields(self) -> None:
        items = await self.provider.search("星际穿越", limit=5)

        self.assertEqual(1, len(items))
        self.assertEqual("42", items[0].remote_id)
        self.assertEqual("HD中字", items[0].remarks)

    async def test_detail_parses_playlist_and_cleans_html(self) -> None:
        detail = await self.provider.detail("42")

        self.assertEqual("穿越星际寻找新的家园。", detail.summary)
        self.assertEqual("https://cdn.example/movie.m3u8", detail.play_lines[0].episodes[0].play_url)
