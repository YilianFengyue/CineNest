"""解析 MacCMS 的 vod_play_from / vod_play_url 字段。"""
from __future__ import annotations

from urllib.parse import urlparse

from .models import Episode, PlayLine


def is_http_url(value: str) -> bool:
    """仅保留播放器可交付的 HTTP(S) URL。"""

    parsed = urlparse(value.strip())
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def parse_episode_group(raw_group: str) -> list[Episode]:
    """解析 `第01集$url#第02集$url`，跳过格式损坏或非 HTTP URL。"""

    episodes: list[Episode] = []
    for index, raw_episode in enumerate(raw_group.split("#"), start=1):
        raw_episode = raw_episode.strip()
        if not raw_episode:
            continue
        if "$" in raw_episode:
            name, play_url = raw_episode.split("$", maxsplit=1)
        else:
            name, play_url = f"第{index}集", raw_episode
        play_url = play_url.strip()
        if not is_http_url(play_url):
            continue
        episodes.append(Episode(name=name.strip() or f"第{index}集", play_url=play_url))
    return episodes


def parse_play_lines(raw_from: str | None, raw_url: str | None) -> list[PlayLine]:
    """解析 MacCMS 多线路字段，线路之间通常以 `$$$` 分隔。"""

    if not raw_url:
        return []
    names = [value.strip() for value in (raw_from or "").split("$$$")]
    groups = raw_url.split("$$$")
    lines: list[PlayLine] = []
    for index, group in enumerate(groups):
        episodes = parse_episode_group(group)
        if not episodes:
            continue
        name = names[index] if index < len(names) and names[index] else f"线路{index + 1}"
        lines.append(PlayLine(name=name, episodes=episodes))
    return lines
