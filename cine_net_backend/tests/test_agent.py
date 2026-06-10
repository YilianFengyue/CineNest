import json
from unittest import TestCase
from unittest.mock import patch

from langchain_core.messages import ToolMessage

from services.agent.factory import (
    AgentServiceUnavailableError,
    _attachment_from_tool_message,
    _friendly_upstream_error,
    _message_payload,
)
from services.assets.models import AssetRecord, AgentInputAttachment


class AgentAttachmentTests(TestCase):
    def test_recommendation_tool_message_becomes_flutter_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "microdesign.v1.1", "query": "功夫熊猫", "posts": []}),
            name="build_recommendation_feed",
            tool_call_id="call-1",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("recommendation_feed", attachment.type)
        self.assertEqual("功夫熊猫", attachment.payload["query"])

    def test_interactive_tool_message_becomes_flutter_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "microdesign.v1.1", "cards": [], "actions": []}),
            name="build_interactive_answer",
            tool_call_id="call-2",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("interactive_cards", attachment.type)
        self.assertEqual("microdesign.v1.1", attachment.schema_version)

    def test_news_tool_message_becomes_flutter_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "microdesign.v1.1", "items": []}),
            name="collect_movie_news",
            tool_call_id="call-3",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("news_feed", attachment.type)

    def test_news_generate_tool_message_becomes_task_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"id": "news-task-1", "query": "沙丘", "status": "queued"}),
            name="generate_movie_news",
            tool_call_id="call-4",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("news_task", attachment.type)
        self.assertEqual("news-task-1", attachment.payload["id"])

    def test_bili_tool_message_becomes_companion_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "bili.v1", "movie": "你的名字", "videos": []}),
            name="build_bili_companion",
            tool_call_id="call-bili",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("bilibili_companion", attachment.type)
        self.assertEqual("你的名字", attachment.payload["movie"])

    def test_phone_tool_message_becomes_task_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "phone_task.v2", "task_id": "phone-1", "status": "queued"}),
            name="start_phone_task",
            tool_call_id="call-phone",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("phone_task", attachment.type)
        self.assertEqual("phone-1", attachment.payload["task_id"])

    def test_non_visual_tool_does_not_become_attachment(self) -> None:
        message = ToolMessage(content="{}", name="get_backend_status", tool_call_id="call-5")

        self.assertIsNone(_attachment_from_tool_message(message))

    def test_upstream_502_becomes_short_friendly_error(self) -> None:
        error = RuntimeError("large upstream traceback")
        error.status_code = 502

        friendly = _friendly_upstream_error(error)

        self.assertIsInstance(friendly, AgentServiceUnavailableError)
        self.assertIn("HTTP 502", str(friendly))
        self.assertNotIn("traceback", str(friendly))

    def test_image_attachment_is_text_note_for_non_vision_model(self) -> None:
        record = AssetRecord(
            id="asset-1",
            kind="image",
            filename="poster.png",
            stored_name="asset-1.png",
            mime="image/png",
            size=10,
            created_at="2026-06-04T00:00:00+00:00",
            url="/api/assets/asset-1",
        )
        with (
            patch("services.agent.factory.get_asset", return_value=record),
            patch("services.agent.factory.model_supports_images", return_value=False),
        ):
            payload = _message_payload(
                "看看这张图",
                [AgentInputAttachment(asset_id="asset-1")],
                model="fast",
            )

        self.assertIsInstance(payload, list)
        self.assertNotIn("image_url", {part.get("type") for part in payload})
        self.assertIn("不支持视觉输入", payload[-1]["text"])
