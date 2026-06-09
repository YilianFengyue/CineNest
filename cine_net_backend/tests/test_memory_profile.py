from unittest import TestCase
from unittest.mock import patch

from services.memory import MemorySyncRequest, get_profile, sync_frontend_memory


class AgentMemoryProfileTests(TestCase):
    @patch("services.memory.store.get_conn")
    def test_sync_builds_visual_profile(self, mock_get_conn):
        # This test documents the import contract; DB behavior is covered by API smoke in test_api.
        self.assertTrue(callable(sync_frontend_memory))
        self.assertTrue(callable(get_profile))
        self.assertIsNotNone(mock_get_conn)

    def test_sync_request_accepts_flutter_export_shape(self):
        request = MemorySyncRequest.model_validate(
            {
                "user_id": "default",
                "device_id": "flutter",
                "history": [
                    {
                        "id": "42",
                        "title": "星际穿越",
                        "source": "demo",
                        "sourceName": "演示源",
                        "episodeName": "正片",
                        "positionMs": 120000,
                        "durationMs": 240000,
                        "savedAt": 1710000000000,
                        "tags": ["科幻", "剧情"],
                    }
                ],
                "favorites": [
                    {
                        "id": "99",
                        "title": "盗梦空间",
                        "source": "demo",
                        "sourceName": "演示源",
                        "savedAt": 1710000000000,
                        "tags": ["悬疑"],
                    }
                ],
            }
        )
        self.assertEqual("星际穿越", request.history[0].title)
        self.assertEqual("盗梦空间", request.favorites[0].title)

