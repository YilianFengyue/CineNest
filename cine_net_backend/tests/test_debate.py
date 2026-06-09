from unittest import IsolatedAsyncioTestCase
from unittest.mock import patch

from services.debate import DebateRecommendationRequest, build_debate_recommendation
from services.memory.models import AgentProfile, ProfileTag


class DebateRecommendationTests(IsolatedAsyncioTestCase):
    async def test_fallback_debate_shape(self):
        profile = AgentProfile(
            user_id="default",
            summary="用户偏好科幻和悬疑。",
            taste_tags=[ProfileTag(name="科幻", weight=4, count=2)],
        )
        with patch("services.debate.service.get_profile", return_value=profile), patch(
            "services.debate.service.get_chat_model", side_effect=RuntimeError("no key")
        ):
            envelope = await build_debate_recommendation(
                DebateRecommendationRequest(
                    movie="星际穿越",
                    overview="父亲穿越虫洞寻找新家园。",
                    source_name="演示源",
                    tags=["科幻", "剧情"],
                )
            )
        self.assertEqual("fallback", envelope.generated_by)
        self.assertEqual("星际穿越", envelope.result.movie)
        self.assertGreaterEqual(envelope.result.final_score, 0)
        self.assertLessEqual(envelope.result.final_score, 100)
        self.assertTrue(envelope.result.highlight_moments)
        self.assertTrue(envelope.result.render_sections)
        self.assertIn(
            "hot_comments",
            {section.type for section in envelope.result.render_sections},
        )
        self.assertIn(
            "highlight_buttons",
            {section.type for section in envelope.result.render_sections},
        )
        self.assertEqual(
            "seek_or_hint",
            envelope.result.highlight_moments[0].action["type"],
        )
        self.assertIn("科幻", envelope.result.taste_agent)
