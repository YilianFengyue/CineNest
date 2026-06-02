from unittest import TestCase

from services.resources.playlist import parse_episode_group, parse_play_lines


class PlaylistParserTests(TestCase):
    def test_parse_multiple_lines_and_episodes(self) -> None:
        lines = parse_play_lines(
            "line-a$$$line-b",
            "第01集$https://cdn.example/1.m3u8#第02集$https://cdn.example/2.m3u8"
            "$$$正片$https://cdn.example/movie.mp4",
        )

        self.assertEqual(["line-a", "line-b"], [line.name for line in lines])
        self.assertEqual(["第01集", "第02集"], [episode.name for episode in lines[0].episodes])
        self.assertEqual("https://cdn.example/movie.mp4", lines[1].episodes[0].play_url)

    def test_skip_malformed_and_non_http_urls(self) -> None:
        episodes = parse_episode_group(
            "坏数据#脚本$javascript:alert(1)#相对地址$/relative.m3u8#正片$https://cdn.example/a.m3u8"
        )

        self.assertEqual(1, len(episodes))
        self.assertEqual("正片", episodes[0].name)
