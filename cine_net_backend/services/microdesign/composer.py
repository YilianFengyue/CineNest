"""把资源聚合结果确定性地组合为帖子和动态海报 blocks。"""
from __future__ import annotations

from services.catalog.models import CatalogMovie
from services.resources.models import AggregatedMediaItem, MediaResourceDetail, ResourceSearchResponse

from .models import ContentBlock, MicroDesignPost, PosterSpec


def _style_for(category: str) -> str:
    lowered = category.lower()
    if any(key in lowered for key in ("科幻", "奇幻", "动漫", "动画")):
        return "neon"
    if any(key in lowered for key in ("动作", "战争", "犯罪", "悬疑")):
        return "contrast"
    return "warm"


def _reason_for(item: AggregatedMediaItem) -> str:
    source_hint = f"已聚合 {len(item.sources)} 条可继续解析的线路"
    if item.remarks:
        return f"{item.remarks}，{source_hint}。"
    if item.category:
        return f"这部{item.category}已进入资源池，{source_hint}。"
    return f"这部作品{source_hint}，可以继续查看播放详情。"


def compose_recommendation_posts(
    response: ResourceSearchResponse,
    *,
    limit: int = 10,
) -> list[MicroDesignPost]:
    """基于真实聚合结果生成帖子，不让模型编造播放线路。"""

    posts: list[MicroDesignPost] = []
    for item in response.items[:limit]:
        if not item.sources:
            continue
        primary = item.sources[0]
        subtitle = " · ".join(value for value in (item.category, item.year, item.remarks) if value)
        blocks = [
            ContentBlock(
                type="posterRow",
                data={
                    "cover": item.cover_url,
                    "summary": _reason_for(item),
                    "tags": [tag for tag in (item.category, item.remarks) if tag],
                },
            )
        ]
        posts.append(
            MicroDesignPost(
                id=f"{primary.provider_id}:{primary.remote_id}",
                title=item.title,
                subtitle=subtitle,
                cover_url=item.cover_url,
                recommend_reason=_reason_for(item),
                has_video_source=True,
                source_count=len(item.sources),
                primary_resource=primary,
                blocks=blocks,
            )
        )
    return posts


def compose_catalog_post(
    movie: CatalogMovie,
    resource: AggregatedMediaItem,
    *,
    recommend_reason: str = "",
) -> MicroDesignPost:
    """合并资料库与播放资源，生成 Flutter 可直接渲染的推荐帖子。"""

    primary = resource.sources[0]
    reason = recommend_reason or (
        f"{movie.rating:.1f} 分，已确认 {len(resource.sources)} 个可用资源站。"
        if movie.rating is not None
        else f"已确认 {len(resource.sources)} 个可用资源站。"
    )
    tags = [*movie.genres[:3]]
    if resource.category and resource.category not in tags:
        tags.append(resource.category)
    blocks = [
        ContentBlock(
            type="posterRow",
            data={
                "cover": movie.poster_url or resource.cover_url,
                "score": movie.rating,
                "summary": movie.overview or reason,
                "tags": tags,
            },
        )
    ]
    return MicroDesignPost(
        id=f"{primary.provider_id}:{primary.remote_id}",
        catalog_id=movie.catalog_id,
        title=movie.title,
        subtitle=" · ".join(value for value in (movie.year, resource.category, resource.remarks) if value),
        cover_url=movie.poster_url or resource.cover_url,
        backdrop_url=movie.backdrop_url,
        rating=movie.rating,
        rating_count=movie.rating_count,
        overview=movie.overview,
        genres=movie.genres,
        recommend_reason=reason,
        has_video_source=True,
        source_count=len(resource.sources),
        primary_resource=primary,
        blocks=blocks,
    )


def compose_poster(detail: MediaResourceDetail) -> PosterSpec:
    """将真实资源详情组合为动态海报；前端可按 blocks 渲染。"""

    style = _style_for(detail.category)
    subtitle = " · ".join(value for value in (detail.category, detail.year, detail.remarks) if value)
    blocks: list[ContentBlock] = [
        ContentBlock(
            type="banner",
            data={"image": detail.cover_url, "title": detail.title, "subtitle": subtitle, "style": style},
        ),
        ContentBlock(type="tagRow", data={"tags": [tag for tag in (detail.category, detail.remarks) if tag]}),
        ContentBlock(type="heading", data={"text": "影片简介"}),
        ContentBlock(type="text", data={"text": detail.summary or "暂无简介"}),
        ContentBlock(type="heading", data={"text": "可用线路"}),
    ]
    for line in detail.play_lines:
        first_episode = line.episodes[0]
        blocks.append(
            ContentBlock(
                type="videoBar",
                data={
                    "title": f"{line.name} · {first_episode.name}",
                    "cover": detail.cover_url,
                    "play_url": first_episode.play_url,
                    "episode_count": len(line.episodes),
                },
            )
        )
    return PosterSpec(
        id=f"{detail.provider_id}:{detail.remote_id}",
        style=style,
        title=detail.title,
        subtitle=subtitle,
        resource=detail,
        blocks=blocks,
    )


def compose_catalog_poster(
    movie: CatalogMovie,
    detail: MediaResourceDetail,
    *,
    recommend_reason: str = "",
) -> PosterSpec:
    """用资料库丰富动态海报：封面、背景、评分、简介和真实播放线路。"""

    style = _style_for(" ".join([*movie.genres, detail.category]))
    reason = recommend_reason or "根据你的观影意图与当前可用资源，为你精选这部作品。"
    subtitle = " · ".join(value for value in (movie.original_title, movie.year, detail.remarks) if value)
    tags = [*movie.genres[:4]]
    if detail.category and detail.category not in tags:
        tags.append(detail.category)
    blocks: list[ContentBlock] = [
        ContentBlock(
            type="banner",
            data={
                "image": movie.backdrop_url or movie.poster_url or detail.cover_url,
                "poster": movie.poster_url or detail.cover_url,
                "title": movie.title,
                "subtitle": subtitle,
                "style": style,
            },
        ),
    ]
    if movie.rating is not None:
        blocks.append(ContentBlock(type="rating", data={"score": movie.rating, "label": movie.provider_name}))
    if tags:
        blocks.append(ContentBlock(type="tagRow", data={"tags": tags}))
    blocks.extend(
        [
            ContentBlock(type="heading", data={"text": "推荐理由"}),
            ContentBlock(type="text", data={"text": reason}),
            ContentBlock(type="heading", data={"text": "影片简介"}),
            ContentBlock(type="text", data={"text": movie.overview or detail.summary or "暂无简介"}),
            ContentBlock(type="heading", data={"text": "可用线路"}),
        ]
    )
    for line in detail.play_lines:
        if not line.episodes:
            continue
        first_episode = line.episodes[0]
        blocks.append(
            ContentBlock(
                type="videoBar",
                data={
                    "title": f"{line.name} · {first_episode.name}",
                    "cover": movie.poster_url or detail.cover_url,
                    "play_url": first_episode.play_url,
                    "episode_count": len(line.episodes),
                },
            )
        )
    return PosterSpec(
        id=f"{detail.provider_id}:{detail.remote_id}",
        catalog_id=movie.catalog_id,
        style=style,
        title=movie.title,
        subtitle=subtitle,
        recommend_reason=reason,
        catalog=movie,
        resource=detail,
        blocks=blocks,
    )
