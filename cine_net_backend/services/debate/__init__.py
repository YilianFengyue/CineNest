"""辩论式推荐服务。"""

from .models import DebateRecommendation, DebateRecommendationEnvelope, DebateRecommendationRequest
from .service import build_debate_recommendation

__all__ = [
    "DebateRecommendation",
    "DebateRecommendationEnvelope",
    "DebateRecommendationRequest",
    "build_debate_recommendation",
]

