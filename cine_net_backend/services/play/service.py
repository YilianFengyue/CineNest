"""统一播放描述服务。"""
from __future__ import annotations

from services.resources import get_resource_aggregator
from services.resources.models import PlayDescriptor


async def resolve_play(provider_id: str, remote_id: str) -> PlayDescriptor:
    detail = await get_resource_aggregator().detail(provider_id, remote_id)
    for line in detail.play_lines:
        for episode in line.episodes:
            return PlayDescriptor(
                type="direct",
                play_url=episode.play_url,
                provider_id=provider_id,
                remote_id=remote_id,
                title=detail.title,
                line_name=line.name,
                episode_name=episode.name,
            )
    raise LookupError("该资源未解析出可播放地址")
