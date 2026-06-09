"""一次 LLM 调用模拟影视推荐委员会。"""
from __future__ import annotations

from langchain_core.messages import HumanMessage, SystemMessage

from services.llm import get_chat_model
from services.memory import get_profile

from .models import (
    DebateRecommendation,
    DebateRecommendationEnvelope,
    DebateRecommendationRequest,
    DebateRenderItem,
    DebateRenderReply,
    DebateRenderSection,
    HighlightMoment,
)


SYSTEM_PROMPT = """\
你是 CineNest 的“影视推荐委员会”。
你必须模拟 4 个专家视角，但只输出一个 JSON 结构：
1. 口味匹配官：是否符合用户长期画像
2. 资源可用官：是否有播放源、清晰度或解说友好度
3. 口碑分析官：根据输入中的评分、热度、简介判断，不得编造不存在的评分
4. 反方审查官：指出为什么这部作品可能不适合用户
最后由主推荐官给出 0-100 分、理由、风险、是否推荐。
精彩片段只能基于简介和常规叙事位置表达；没有可靠时间轴时不要编造具体分钟。
render_sections 用于播放器评论区渲染：
- hot_comments：把专家意见写成类似热门评论的列表，可带 reply_preview 楼中楼
- highlight_buttons：精彩片段按钮，action.type 使用 seek_or_hint；没有真实时间轴时 start_ms 留空
- danmaku_seeds：短弹幕种子
使用简洁中文。
"""


def _highlight_action(label: str, approx_time: str = "") -> dict:
    return {
        "type": "seek_or_hint",
        "label": label,
        "approx_time": approx_time,
        "start_ms": None,
        "episode_index": 0,
    }


def _render_sections(result: DebateRecommendation) -> list[DebateRenderSection]:
    hot_comments = DebateRenderSection(
        type="hot_comments",
        title="最热评论",
        subtitle="AI 推荐委员会",
        items=[
            DebateRenderItem(
                id="taste",
                author="口味匹配官",
                badge="AI",
                avatar_seed="taste",
                content=result.taste_agent,
                likes=max(42, result.final_score + 3),
                reply_preview=[
                    DebateRenderReply(author="主推荐官", content=result.final_reason, likes=max(12, result.final_score // 2))
                ],
            ),
            DebateRenderItem(
                id="resource",
                author="资源可用官",
                badge="AI",
                avatar_seed="resource",
                content=result.resource_agent,
                likes=max(30, result.final_score - 8),
            ),
            DebateRenderItem(
                id="review",
                author="口碑分析官",
                badge="AI",
                avatar_seed="review",
                content=result.review_agent,
                likes=max(28, result.final_score - 12),
                reply_preview=[
                    DebateRenderReply(author="反方审查官", content=result.critic_agent, likes=max(8, 100 - result.final_score))
                ],
            ),
            DebateRenderItem(
                id="critic",
                author="反方审查官",
                badge="AI",
                avatar_seed="critic",
                content=result.critic_agent,
                likes=max(16, 105 - result.final_score),
            ),
        ],
    )
    highlights = DebateRenderSection(
        type="highlight_buttons",
        title="精彩片段",
        subtitle="没有真实时间轴时只做提示，不硬跳分钟",
        items=[
            DebateRenderItem(
                id=f"highlight-{index}",
                label=item.label,
                why=item.why,
                button_text=item.button_text or "查看片段",
                action=item.action or _highlight_action(item.label, item.approx_time),
            )
            for index, item in enumerate(result.highlight_moments)
        ],
    )
    danmaku = DebateRenderSection(
        type="danmaku_seeds",
        title="弹幕种子",
        seeds=[
            f"口味官：{result.final_score} 分不是乱给的",
            "资源官：先看当前源稳不稳",
            "反方官：别在困的时候硬看",
            "主推荐官：适合就点收藏",
        ],
    )
    return [hot_comments, highlights, danmaku]


def _complete_result(result: DebateRecommendation) -> DebateRecommendation:
    moments = []
    for item in result.highlight_moments:
        if not item.action:
            item.action.update(_highlight_action(item.label, item.approx_time))
        if not item.button_text:
            item.button_text = "查看片段"
        moments.append(item)
    result.highlight_moments = moments
    if not result.render_sections:
        result.render_sections = _render_sections(result)
    return result


def _fallback(request: DebateRecommendationRequest, profile_summary: str) -> DebateRecommendationEnvelope:
    tags = set(request.tags)
    score = 68
    if request.playable:
        score += 8
    if request.overview:
        score += 6
    if tags.intersection({"科幻", "悬疑", "剧情", "动画", "喜剧", "动作"}):
        score += 6
    score = max(0, min(96, score))
    resource = "当前条目来自本地聚合器，可继续用现有片源播放。" if request.playable else "暂未确认可播放源，建议先换源搜索。"
    result = DebateRecommendation(
        movie=request.movie,
        taste_agent=f"结合画像看，{profile_summary or '当前画像数据还不多'}；这部作品可作为候选。",
        resource_agent=resource,
        review_agent=(
            f"输入评分为 {request.rating}，可作为口碑参考。"
            if request.rating
            else "当前没有可靠评分输入，先根据简介和用户画像做保守判断。"
        ),
        critic_agent="如果用户现在只想碎片化放松，建议留意片长、节奏和题材门槛。",
        chair_agent="委员会倾向给出谨慎推荐，优先作为今晚候选而不是盲推。",
        final_score=score,
        final_reason=f"《{request.movie}》与现有画像存在一定重合，并且播放链路可用。" if request.playable else f"《{request.movie}》有兴趣点，但资源状态需要先确认。",
        risk_tips=["片源质量可能因站点变化波动", "没有真实时间轴时不生成精确片段时间"],
        highlight_moments=[
            HighlightMoment(
                label="开场设定段",
                why="适合快速判断题材、质感和是否合胃口",
                action=_highlight_action("开场设定段"),
            ),
            HighlightMoment(
                label="中段冲突升级",
                why="通常最能体现人物关系和核心看点",
                action=_highlight_action("中段冲突升级"),
            ),
            HighlightMoment(
                label="结尾情绪回收",
                why="适合判断这部作品是否值得收藏或二刷",
                spoiler_level="medium",
                action=_highlight_action("结尾情绪回收"),
            ),
        ],
        recommend=score >= 72,
        confidence=0.58,
        evidence=[item for item in [request.source_name, request.year or "", "本地画像"] if item],
    )
    result = _complete_result(result)
    return DebateRecommendationEnvelope(
        user_id=request.user_id,
        generated_by="fallback",
        profile_summary=profile_summary,
        result=result,
    )


async def build_debate_recommendation(request: DebateRecommendationRequest) -> DebateRecommendationEnvelope:
    profile = get_profile(request.user_id)
    profile_summary = profile.summary
    try:
        model = get_chat_model(request.model).with_structured_output(DebateRecommendation)
        result = await model.ainvoke(
            [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(
                    content=(
                        f"用户画像：{profile_summary}\n"
                        f"偏好标签：{[tag.name for tag in profile.taste_tags[:6]]}\n"
                        f"避雷标签：{[tag.name for tag in profile.avoid_tags[:4]]}\n"
                        f"片名：{request.movie}\n"
                        f"年份：{request.year or '未知'}\n"
                        f"简介：{request.overview or '暂无'}\n"
                        f"片源：{request.source_name or '未知'}\n"
                        f"当前集：{request.episode_name or '未指定'}\n"
                        f"是否可播放：{request.playable}\n"
                        f"评分：{request.rating or '暂无可靠输入'}\n"
                        f"标签：{request.tags}\n"
                    )
                ),
            ]
        )
        if not isinstance(result, DebateRecommendation):
            result = DebateRecommendation.model_validate(result)
        result = _complete_result(result)
        return DebateRecommendationEnvelope(
            user_id=request.user_id,
            generated_by="llm",
            profile_summary=profile_summary,
            result=result,
        )
    except Exception:
        return _fallback(request, profile_summary)
