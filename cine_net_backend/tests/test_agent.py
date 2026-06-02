import json
from unittest import TestCase

from langchain_core.messages import ToolMessage

from services.agent.factory import AgentServiceUnavailableError, _attachment_from_tool_message, _friendly_upstream_error


class AgentAttachmentTests(TestCase):
    def test_recommendation_tool_message_becomes_flutter_attachment(self) -> None:
        message = ToolMessage(
            content=json.dumps({"schema_version": "microdesign.v1", "query": "功夫熊猫", "posts": []}),
            name="build_recommendation_feed",
            tool_call_id="call-1",
        )

        attachment = _attachment_from_tool_message(message)

        self.assertIsNotNone(attachment)
        self.assertEqual("recommendation_feed", attachment.type)
        self.assertEqual("功夫熊猫", attachment.payload["query"])

    def test_non_visual_tool_does_not_become_attachment(self) -> None:
        message = ToolMessage(content="{}", name="get_backend_status", tool_call_id="call-2")

        self.assertIsNone(_attachment_from_tool_message(message))

    def test_upstream_502_becomes_short_friendly_error(self) -> None:
        error = RuntimeError("large upstream traceback")
        error.status_code = 502

        friendly = _friendly_upstream_error(error)

        self.assertIsInstance(friendly, AgentServiceUnavailableError)
        self.assertIn("HTTP 502", str(friendly))
        self.assertNotIn("traceback", str(friendly))
