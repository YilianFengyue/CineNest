"""一次 LLM 调用模拟影视推荐委员会。"""
from __future__ import annotations

import json
import re

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
你是 CineNest 播放器评论区里的 AI 推荐委员会。
你要模拟 4 个 AI 评论员 + 1 个主推荐官，语气像 B 站热门评论: 口语化、有个性、带点情绪，但言之有物。

角色和写法:
1. taste_agent 口味匹配官: 像资深片友给建议。用画像标签说话，2-3 句，可以用 你/直接冲/慎入 之类口语。
2. resource_agent 资源可用官: 像找源老哥汇报。说清片源名、清晰度、字幕，1-2 句。
3. review_agent 口碑分析官: 像写短评的人，带评分讨论。2-3 句，引用评分时必须用输入的评分，禁止编造。
4. critic_agent 反方审查官: 像唱反调的毒舌评论。必须指出具体缺点，1-2 句，别泛泛说可能不适合。
5. chair_agent 主推荐官: 像置顶总结评论，给结论。1-2 句。

final_reason: 一句话结论，像评论区置顶。
risk_tips: 每条像弹幕里的短提醒。
highlight_moments: 基于简介和常规叙事位置推荐精彩片段。approx_time 填你对这部作品的大致时间估计(如 "约1h20m" "前30分钟")，知名场景尽量给出估计；完全没把握时才留空。

必须围绕输入片名作答。简介/评分/画像不足时明确说资料不多，仍要基于片名和标签给出判断。
"""

JSON_PROMPT = """\
请只输出合法 JSON，不要 Markdown，不要代码块。
JSON 字段必须包含：
schema_version, movie, committee_title, taste_agent, resource_agent, review_agent,
critic_agent, chair_agent, final_score, final_reason, risk_tips,
highlight_moments, recommend, confidence, evidence。

highlight_moments 每项包含：
label, why, spoiler_level, approx_time。

不要输出 render_sections，评论区渲染结构由后端生成。
没有真实时间轴时 approx_time 留空，不要编造具体分钟。
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


def _json_from_text(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", cleaned, re.S)
        if match is None:
            raise
        data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise ValueError("LLM JSON root is not object")
    if "result" in data and isinstance(data["result"], dict):
        return data["result"]
    return data


def _normalize_result_payload(data: dict, request: DebateRecommendationRequest) -> dict:
    data.setdefault("schema_version", "debate.v1")
    data["movie"] = request.movie
    data.setdefault("committee_title", "AI 推荐委员会结论")
    data.setdefault("risk_tips", [])
    data.setdefault("highlight_moments", [])
    data.setdefault("render_sections", [])
    data.setdefault("evidence", [])
    data.setdefault("confidence", 0.72)
    data.setdefault("recommend", True)
    try:
        confidence = float(data.get("confidence") or 0.72)
        data["confidence"] = max(0.0, min(1.0, confidence / 100 if confidence > 1 else confidence))
    except (TypeError, ValueError):
        data["confidence"] = 0.72
    try:
        data["final_score"] = max(0, min(100, int(data.get("final_score") or 72)))
    except (TypeError, ValueError):
        data["final_score"] = 72
    for field in ("risk_tips", "evidence"):
        value = data.get(field)
        if value is None:
            data[field] = []
        elif isinstance(value, list):
            data[field] = [str(item) for item in value if str(item).strip()]
        else:
            data[field] = [str(value)]
    if isinstance(data.get("recommend"), str):
        data["recommend"] = data["recommend"].strip().lower() in {"true", "yes", "1", "推荐", "是"}
    level_map = {
        "无": "low",
        "低": "low",
        "轻微": "low",
        "少量": "low",
        "low": "low",
        "中": "medium",
        "中等": "medium",
        "medium": "medium",
        "高": "high",
        "严重": "high",
        "high": "high",
    }
    normalized_moments = []
    for index, item in enumerate(data.get("highlight_moments") or []):
        if not isinstance(item, dict):
            continue
        label = str(item.get("label") or f"精彩片段 {index + 1}")
        raw_level = str(item.get("spoiler_level") or "low").strip().lower()
        item["label"] = label
        item["why"] = str(item.get("why") or "适合判断这部作品是否合胃口")
        item["spoiler_level"] = level_map.get(raw_level, "low")
        item["approx_time"] = str(item.get("approx_time") or "")
        item["button_text"] = str(item.get("button_text") or "查看片段")
        item["action"] = item.get("action") if isinstance(item.get("action"), dict) else _highlight_action(label)
        normalized_moments.append(item)
    if not normalized_moments:
        normalized_moments = [
            {
                "label": "开场设定段",
                "why": f"快速判断《{request.movie}》的题材质感和是否合胃口",
                "spoiler_level": "low",
                "approx_time": "",
                "button_text": "查看片段",
                "action": _highlight_action("开场设定段"),
            }
        ]
    data["highlight_moments"] = normalized_moments
    for field in ("taste_agent", "resource_agent", "review_agent", "critic_agent", "chair_agent", "final_reason"):
        data[field] = str(data.get(field) or "")
    if request.movie not in data["final_reason"]:
        data["final_reason"] = f"《{request.movie}》：{data['final_reason']}"
    if request.movie not in data["taste_agent"]:
        data["taste_agent"] = f"针对《{request.movie}》，{data['taste_agent']}"
    return data


async def _invoke_llm_result(
    request: DebateRecommendationRequest,
    profile_summary: str,
    taste_tags: list[str],
    avoid_tags: list[str],
) -> tuple[DebateRecommendation, str]:
    model_id = "default"
    model = get_chat_model(model_id)
    response = await model.ainvoke(
        [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(
                content=(
                    f"{JSON_PROMPT}\n\n"
                    f"用户画像：{profile_summary}\n"
                    f"偏好标签：{taste_tags}\n"
                    f"避雷标签：{avoid_tags}\n"
                            f"片名：{request.movie}\n"
                            f"注意：所有结论必须明确围绕《{request.movie}》，不得替换成其它作品。\n"
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
    result = DebateRecommendation.model_validate(_normalize_result_payload(_json_from_text(str(response.content)), request))
    return _complete_result(result), model_id


def _fallback(
    request: DebateRecommendationRequest,
    profile_summary: str,
    *,
    reason: str = "",
) -> DebateRecommendationEnvelope:
    movie = request.movie
    tags = set(request.tags)
    tags_str = "、".join(tags) if tags else ""
    year_str = f"（{request.year}年）" if request.year else ""
    overview_short = (request.overview or "")[:80]
    source_str = request.source_name or "未知片源"

    score = 68
    if request.playable:
        score += 8
    if request.overview:
        score += 6
    if tags.intersection({"科幻", "悬疑", "剧情", "动画", "喜剧", "动作"}):
        score += 6
    score = max(0, min(96, score))

    # ── taste_agent: 结合画像 + 电影标签 ──
    if tags_str and profile_summary and "暂无" not in profile_summary:
        taste_text = f"《{movie}》{year_str}属于{tags_str}类型，结合画像看，{profile_summary}，与用户口味有一定重合。"
    elif tags_str:
        taste_text = f"《{movie}》{year_str}属于{tags_str}类型。当前画像数据还不多，建议先同步观看历史再做精准匹配。"
    else:
        taste_text = f"《{movie}》{year_str}暂无详细标签信息，建议先观看几分钟再判断是否合口味。"

    # ── resource_agent: 片源信息 ──
    if request.playable:
        resource_text = f"当前通过「{source_str}」聚合器已找到《{movie}》的可播放源，可以直接观看。"
    else:
        resource_text = f"《{movie}》当前未确认有可播放源，建议在聚合器中换源搜索。"

    # ── review_agent: 评分 + 简介 ──
    if request.rating and overview_short:
        review_text = f"《{movie}》评分 {request.rating}，{overview_short}{'…' if len(request.overview or '') > 80 else ''}。口碑尚可，值得尝试。"
    elif request.rating:
        review_text = f"《{movie}》评分 {request.rating}，具体口碑需结合观看体验判断。"
    elif overview_short:
        review_text = f"《{movie}》简介：{overview_short}{'…' if len(request.overview or '') > 80 else ''}。暂无可靠评分，按内容看有一定看点。"
    else:
        review_text = f"《{movie}》暂无评分和简介数据，建议先看几分钟再做判断。"

    # ── critic_agent: 反方意见（基于标签和信息完整度）──
    risk_reasons = []
    if not request.overview:
        risk_reasons.append("简介信息缺失，可能存在内容预期偏差")
    if not request.rating:
        risk_reasons.append("没有可靠评分参考")
    if tags.intersection({"恐怖", "惊悚"}):
        risk_reasons.append("包含惊悚/恐怖元素，不适合所有场景")
    if not risk_reasons:
        risk_reasons.append("信息完整度较高，暂无明显风险")
    critic_text = f"关于《{movie}》需要注意：{'；'.join(risk_reasons)}。如果当前只想碎片化放松，建议留意片长和节奏。"

    # ── chair_agent: 综合结论 ──
    if score >= 80:
        chair_text = f"综合各方意见，《{movie}》{year_str}在口味匹配和资源可用性上表现良好，委员会推荐观看。"
    elif score >= 72:
        chair_text = f"《{movie}》{year_str}整体条件合格，委员会谨慎推荐，可作为今晚候选。"
    else:
        chair_text = f"《{movie}》{year_str}当前信息不够充分，委员会建议先浏览几分钟再决定是否继续。"

    # ── final_reason ──
    if request.playable and tags_str:
        final = f"《{movie}》{year_str}是{tags_str}类型作品，有可用播放源，与画像存在重合。"
    elif request.playable:
        final = f"《{movie}》{year_str}播放链路可用，建议直接体验判断。"
    else:
        final = f"《{movie}》{year_str}有兴趣点，但播放源待确认。"

    risk_tips = []
    if not request.playable:
        risk_tips.append("当前片源状态不确定，可能需要换源")
    risk_tips.append("片源质量可能因站点变化波动")
    if not request.overview:
        risk_tips.append("简介缺失，委员会判断基于有限信息")

    result = DebateRecommendation(
        movie=movie,
        taste_agent=taste_text,
        resource_agent=resource_text,
        review_agent=review_text,
        critic_agent=critic_text,
        chair_agent=chair_text,
        final_score=score,
        final_reason=final,
        risk_tips=risk_tips,
        highlight_moments=[
            HighlightMoment(
                label="开场设定段",
                why=f"快速判断《{movie}》的题材质感和是否合胃口",
                action=_highlight_action("开场设定段"),
            ),
            HighlightMoment(
                label="中段冲突升级",
                why=f"《{movie}》中最能体现人物关系和核心看点的段落",
                action=_highlight_action("中段冲突升级"),
            ),
            HighlightMoment(
                label="结尾情绪回收",
                why=f"判断《{movie}》是否值得收藏或二刷",
                spoiler_level="medium",
                action=_highlight_action("结尾情绪回收"),
            ),
        ],
        recommend=score >= 72,
        confidence=0.58,
        evidence=[item for item in [source_str, request.year or "", "本地画像"] if item],
    )
    result = _complete_result(result)
    return DebateRecommendationEnvelope(
        user_id=request.user_id,
        generated_by="fallback",
        fallback_reason=reason,
        profile_summary=profile_summary,
        result=result,
    )


async def build_debate_recommendation(request: DebateRecommendationRequest) -> DebateRecommendationEnvelope:
    profile = get_profile(request.user_id)
    profile_summary = profile.summary
    try:
        result, model_used = await _invoke_llm_result(
            request,
            profile_summary,
            [tag.name for tag in profile.taste_tags[:6]],
            [tag.name for tag in profile.avoid_tags[:4]],
        )
        return DebateRecommendationEnvelope(
            user_id=request.user_id,
            generated_by="llm",
            model_used=model_used,
            profile_summary=profile_summary,
            result=result,
        )
    except Exception as exc:  # noqa: BLE001
        return _fallback(request, profile_summary, reason=f"{type(exc).__name__}: {str(exc)[:240]}")
