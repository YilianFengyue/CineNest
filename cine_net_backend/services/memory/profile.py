"""长期记忆同步与画像构建。"""
from __future__ import annotations

import datetime
from collections import Counter, defaultdict
from typing import Any

from .models import (
    AgentProfile,
    FavoriteSyncItem,
    HistorySyncItem,
    MemorySyncRequest,
    MemorySyncResponse,
    ProfileGraphEdge,
    ProfileGraphNode,
    ProfileMetric,
    ProfileTag,
    ProfileTimelineItem,
)
from .store import (
    create_sync_batch,
    list_memory_items,
    load_profile_payload,
    replace_graph_edges,
    save_profile,
    stable_id,
    upsert_memory_item,
    utc_now,
)

GENRE_KEYWORDS = {
    "科幻": ("科幻", "星际", "宇宙", "未来", "机器人", "AI", "人工智能", "末日"),
    "悬疑": ("悬疑", "推理", "谜", "嫌疑", "侦探", "案件", "反转"),
    "犯罪": ("犯罪", "黑帮", "警匪", "毒", "杀手", "罪"),
    "喜剧": ("喜剧", "搞笑", "欢乐", "爆笑", "熊猫"),
    "动作": ("动作", "特工", "战争", "格斗", "功夫", "英雄"),
    "爱情": ("爱情", "恋爱", "初恋", "婚姻", "情感"),
    "动画": ("动画", "动漫", "番", "皮克斯", "宫崎骏"),
    "恐怖": ("恐怖", "惊悚", "鬼", "灵异", "诅咒"),
    "剧情": ("剧情", "人生", "家庭", "成长", "人性"),
    "纪录": ("纪录", "纪实", "自然", "历史"),
}

FORMAT_KEYWORDS = {
    "电影": ("电影", "片"),
    "剧集": ("第", "集", "季", "剧"),
    "动画": ("动画", "动漫", "番"),
    "解说友好": ("解说", "短评", "片段"),
}


def _epoch_ms_to_iso(value: int) -> str:
    if value <= 0:
        return utc_now()
    return datetime.datetime.fromtimestamp(value / 1000, datetime.timezone.utc).isoformat()


def _detect_tags(title: str, tags: list[str]) -> list[str]:
    text = f"{title} {' '.join(tags)}"
    detected = [tag for tag, keys in GENRE_KEYWORDS.items() if any(key in text for key in keys)]
    for tag in tags:
        cleaned = str(tag).strip()
        if cleaned and cleaned not in detected:
            detected.append(cleaned)
    return detected[:8]


def _format_tags(title: str, episode_name: str | None = None) -> list[str]:
    text = f"{title} {episode_name or ''}"
    detected = [tag for tag, keys in FORMAT_KEYWORDS.items() if any(key in text for key in keys)]
    return detected or ["影视"]


def _history_weight(item: HistorySyncItem) -> float:
    if item.durationMs <= 0:
        return 1.2
    progress = max(0.0, min(1.0, item.positionMs / item.durationMs))
    return 1.0 + progress * 2.0


def sync_frontend_memory(request: MemorySyncRequest) -> MemorySyncResponse:
    payload = request.model_dump()
    batch_id = create_sync_batch(
        user_id=request.user_id,
        device_id=request.device_id,
        history_count=len(request.history),
        favorite_count=len(request.favorites),
        payload=payload,
    )
    upserted = 0
    for item in request.history:
        if not item.title:
            continue
        memory_id = stable_id(request.user_id, "history", item.source, item.id)
        seen_at = _epoch_ms_to_iso(item.savedAt)
        inserted = upsert_memory_item(
            item_id=memory_id,
            user_id=request.user_id,
            memory_type="watch_history",
            subject=item.title,
            relation="watched",
            object_value=item.episodeName or "",
            source=item.sourceName or item.source,
            confidence=0.76,
            weight=_history_weight(item),
            payload={
                **item.model_dump(),
                "taste_tags": _detect_tags(item.title, item.tags),
                "format_tags": _format_tags(item.title, item.episodeName),
                "sync_batch_id": batch_id,
            },
            seen_at=seen_at,
        )
        upserted += int(inserted)
    for item in request.favorites:
        if not item.title:
            continue
        memory_id = stable_id(request.user_id, "favorite", item.source, item.id)
        seen_at = _epoch_ms_to_iso(item.savedAt)
        inserted = upsert_memory_item(
            item_id=memory_id,
            user_id=request.user_id,
            memory_type="favorite",
            subject=item.title,
            relation="likes",
            object_value="",
            source=item.sourceName or item.source,
            confidence=0.9,
            weight=3.0,
            payload={
                **item.model_dump(),
                "taste_tags": _detect_tags(item.title, item.tags),
                "format_tags": _format_tags(item.title, None),
                "sync_batch_id": batch_id,
            },
            seen_at=seen_at,
        )
        upserted += int(inserted)
    profile = rebuild_profile(request.user_id)
    return MemorySyncResponse(
        batch_id=batch_id,
        user_id=request.user_id,
        history_received=len(request.history),
        favorites_received=len(request.favorites),
        upserted=upserted,
        profile_updated_at=profile.updated_at,
    )


def _top_tags(counter: Counter[str], evidence: dict[str, list[str]], limit: int = 8) -> list[ProfileTag]:
    return [
        ProfileTag(name=name, weight=round(weight, 2), count=int(weight), evidence=evidence.get(name, [])[:4])
        for name, weight in counter.most_common(limit)
    ]


def _metric_value(counter: Counter[str], *tags: str) -> float:
    total = sum(counter.values()) or 1
    value = sum(counter.get(tag, 0) for tag in tags) / total
    return round(max(12, min(98, value * 100 + 20)), 1)


def rebuild_profile(user_id: str = "default", *, use_llm: bool = False) -> AgentProfile:
    del use_llm  # 先保留协议位，后续可接 LLM 总结。
    items = list_memory_items(user_id=user_id, limit=800)
    taste_counter: Counter[str] = Counter()
    avoid_counter: Counter[str] = Counter()
    source_counter: Counter[str] = Counter()
    format_counter: Counter[str] = Counter()
    evidence: dict[str, list[str]] = defaultdict(list)
    timeline: list[ProfileTimelineItem] = []
    favorite_titles: list[str] = []
    history_titles: list[str] = []

    for item in items:
        payload = item.payload
        tags = [str(tag) for tag in payload.get("taste_tags") or []]
        formats = [str(tag) for tag in payload.get("format_tags") or []]
        if item.memory_type == "negative_feedback":
            for tag in tags:
                avoid_counter[tag] += item.weight
            continue
        for tag in tags:
            taste_counter[tag] += item.weight
            if item.subject not in evidence[tag]:
                evidence[tag].append(item.subject)
        for tag in formats:
            format_counter[tag] += item.weight
        if item.source:
            source_counter[item.source] += item.weight
        if item.memory_type == "favorite":
            favorite_titles.append(item.subject)
        elif item.memory_type == "watch_history":
            history_titles.append(item.subject)
        timeline.append(
            ProfileTimelineItem(
                at=item.last_seen_at,
                type=item.memory_type,
                title=item.subject,
                subtitle=item.source,
                weight=round(item.weight, 2),
                payload={
                    "relation": item.relation,
                    "episode": item.object,
                    "cover": payload.get("cover"),
                    "year": payload.get("year"),
                },
            )
        )

    taste_tags = _top_tags(taste_counter, evidence)
    avoid_tags = _top_tags(avoid_counter, evidence, limit=5)
    source_distribution = _top_tags(source_counter, defaultdict(list), limit=6)
    format_distribution = _top_tags(format_counter, defaultdict(list), limit=6)
    top_names = [tag.name for tag in taste_tags[:3]]
    if top_names:
        summary = "用户近期偏好：" + "、".join(top_names)
        if favorite_titles:
            summary += f"；收藏信号最强的是《{favorite_titles[0]}》"
        if source_distribution:
            summary += f"；常用片源偏向 {source_distribution[0].name}"
        summary += "。"
    else:
        summary = "暂无足够数据，先同步本地观看历史和收藏。"

    radar_metrics = [
        ProfileMetric(key="logic", label="设定/逻辑", value=_metric_value(taste_counter, "科幻", "悬疑")),
        ProfileMetric(key="emotion", label="情感内核", value=_metric_value(taste_counter, "剧情", "爱情")),
        ProfileMetric(key="thrill", label="刺激强度", value=_metric_value(taste_counter, "动作", "犯罪", "恐怖")),
        ProfileMetric(key="relax", label="轻松程度", value=_metric_value(taste_counter, "喜剧", "动画")),
        ProfileMetric(key="discussion", label="讨论价值", value=_metric_value(taste_counter, "剧情", "悬疑", "科幻")),
    ]

    nodes: list[ProfileGraphNode] = [
        ProfileGraphNode(id=f"user:{user_id}", label="我", type="user", value=10)
    ]
    edges: list[ProfileGraphEdge] = []
    for tag in taste_tags[:8]:
        node_id = f"genre:{tag.name}"
        nodes.append(ProfileGraphNode(id=node_id, label=tag.name, type="genre", value=tag.weight))
        edges.append(
            ProfileGraphEdge(
                id=stable_id(user_id, "edge", "likes", node_id),
                source=f"user:{user_id}",
                target=node_id,
                relation="偏好",
                weight=tag.weight,
                payload={"evidence": tag.evidence},
            )
        )
    for source in source_distribution[:4]:
        node_id = f"source:{source.name}"
        nodes.append(ProfileGraphNode(id=node_id, label=source.name, type="source", value=source.weight))
        edges.append(
            ProfileGraphEdge(
                id=stable_id(user_id, "edge", "uses", node_id),
                source=f"user:{user_id}",
                target=node_id,
                relation="常用",
                weight=source.weight,
            )
        )
    for title in (favorite_titles + history_titles)[:8]:
        node_id = f"movie:{stable_id(title)[:10]}"
        nodes.append(ProfileGraphNode(id=node_id, label=title, type="movie", value=2))
        edges.append(
            ProfileGraphEdge(
                id=stable_id(user_id, "edge", "watched", title),
                source=f"user:{user_id}",
                target=node_id,
                relation="看过/收藏",
                weight=2,
            )
        )

    timeline = sorted(timeline, key=lambda item: item.at, reverse=True)[:30]
    stats = {
        "memory_count": len(items),
        "history_count": sum(1 for item in items if item.memory_type == "watch_history"),
        "favorite_count": sum(1 for item in items if item.memory_type == "favorite"),
        "top_titles": (favorite_titles + history_titles)[:10],
        "updated_source": "rules",
    }
    updated_at = utc_now()
    profile = AgentProfile(
        user_id=user_id,
        summary=summary,
        taste_tags=taste_tags,
        avoid_tags=avoid_tags,
        source_distribution=source_distribution,
        format_distribution=format_distribution,
        radar_metrics=radar_metrics,
        graph_nodes=nodes,
        graph_edges=edges,
        timeline=timeline,
        stats=stats,
        updated_at=updated_at,
    )
    save_profile(user_id, profile.model_dump(), summary)
    replace_graph_edges(user_id, [edge.model_dump() for edge in edges])
    return profile


def get_profile(user_id: str = "default") -> AgentProfile:
    payload = load_profile_payload(user_id)
    if payload:
        return AgentProfile.model_validate(payload)
    return rebuild_profile(user_id)


def agent_context_summary(user_id: str = "default") -> str:
    profile = get_profile(user_id)
    if not profile.stats.get("memory_count"):
        return ""
    tastes = "、".join(tag.name for tag in profile.taste_tags[:5]) or "暂无"
    avoids = "、".join(tag.name for tag in profile.avoid_tags[:3]) or "暂无明确避雷"
    sources = "、".join(tag.name for tag in profile.source_distribution[:3]) or "暂无"
    return (
        f"{profile.summary}\n"
        f"偏好标签：{tastes}\n"
        f"避雷标签：{avoids}\n"
        f"常用片源：{sources}\n"
        "这些信息来自用户本机同步的观看历史、收藏与显式偏好；只能作为推荐依据，影视事实仍需工具核验。"
    )


def remember_chat_signal(user_id: str, message: str) -> None:
    text = message.strip()
    if not text:
        return
    markers = ("喜欢", "不喜欢", "讨厌", "想看", "推荐", "偏好")
    if not any(marker in text for marker in markers):
        return
    tags = _detect_tags(text, [])
    memory_type = "negative_feedback" if any(marker in text for marker in ("不喜欢", "讨厌", "避雷")) else "chat_signal"
    upsert_memory_item(
        item_id=stable_id(user_id, memory_type, text[:120]),
        user_id=user_id,
        memory_type=memory_type,
        subject=text[:120],
        relation="said",
        object_value="",
        source="chat",
        confidence=0.62,
        weight=1.4,
        payload={"text": text, "taste_tags": tags, "format_tags": _format_tags(text)},
    )

