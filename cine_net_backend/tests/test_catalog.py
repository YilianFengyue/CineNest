from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import patch

from services.catalog.douban import DoubanCatalogProvider
from services.catalog.models import CatalogMovie, CatalogProviderConfig, CatalogSourceRef, CatalogTrace
from services.catalog.registry import CatalogRegistry
from services.catalog.service import CatalogService
from services.catalog.tmdb import TMDBCatalogProvider, _auth_headers_and_params


class CatalogRegistryTests(TestCase):
    def test_load_douban_and_tmdb(self) -> None:
        with (
            patch("services.catalog.tmdb.settings.tmdb_read_access_token", ""),
            patch("services.catalog.tmdb.settings.tmdb_api_key", ""),
        ):
            registry = CatalogRegistry()
            self.assertEqual(["tmdb", "douban"], [provider.config.id for provider in registry.list_all()])
            self.assertEqual(["douban"], [provider.config.id for provider in registry.list_available()])


class _StubDouban(DoubanCatalogProvider):
    async def _get(self, url: str):
        return {
            "items": [
                {
                    "id": "1889243",
                    "title": "星际穿越",
                    "card_subtitle": "2014 / 美国 / 科幻",
                    "pic": {"normal": "https://img.example/douban.jpg"},
                    "rating": {"value": 9.4},
                }
            ]
        }


class DoubanProviderTests(IsolatedAsyncioTestCase):
    async def test_hot_maps_rating_poster_and_year(self) -> None:
        provider = _StubDouban(
            CatalogProviderConfig(id="douban", name="豆瓣", kind="douban"),
            timeout_seconds=1,
        )

        movies = await provider.hot()

        self.assertEqual("星际穿越", movies[0].title)
        self.assertEqual("2014", movies[0].year)
        self.assertEqual(9.4, movies[0].rating)
        self.assertEqual("https://img.example/douban.jpg", movies[0].poster_url)


class _StubTMDB(TMDBCatalogProvider):
    async def _get(self, path: str, params=None):
        if path == "/movie/157336":
            return {
                "id": 157336,
                "title": "星际穿越",
                "original_title": "Interstellar",
                "release_date": "2014-11-07",
                "vote_average": 8.5,
                "vote_count": 30000,
                "poster_path": "/poster.jpg",
                "backdrop_path": "/backdrop.jpg",
                "overview": "穿越星际寻找新的家园。",
                "genres": [{"name": "科幻"}, {"name": "冒险"}],
                "credits": {
                    "crew": [{"job": "Director", "name": "Christopher Nolan"}],
                    "cast": [{"name": "Matthew McConaughey"}],
                },
            }
        return {"results": []}


class TMDBProviderTests(IsolatedAsyncioTestCase):
    def test_auth_accepts_api_key_or_read_access_token_in_api_key_field(self) -> None:
        headers, params = _auth_headers_and_params(read_access_token="", api_key="a" * 32)
        self.assertEqual("a" * 32, params["api_key"])
        self.assertNotIn("Authorization", headers)

        headers, params = _auth_headers_and_params(read_access_token="", api_key="eyJ.jwt.token")
        self.assertEqual("Bearer eyJ.jwt.token", headers["Authorization"])
        self.assertNotIn("api_key", params)

    async def test_detail_maps_official_tmdb_fields(self) -> None:
        provider = _StubTMDB(
            CatalogProviderConfig(id="tmdb", name="TMDB", kind="tmdb"),
            timeout_seconds=1,
        )

        movie = await provider.detail("157336")

        self.assertEqual("Interstellar", movie.original_title)
        self.assertEqual(["科幻", "冒险"], movie.genres)
        self.assertEqual(["Christopher Nolan"], movie.directors)
        self.assertEqual("https://image.tmdb.org/t/p/w780/backdrop.jpg", movie.backdrop_url)


class _FakeCatalogProvider:
    def __init__(self, provider_id: str, *, error: Exception | None = None) -> None:
        self.config = SimpleNamespace(id=provider_id, name=provider_id, kind=provider_id, enabled=True, priority=1)
        self.configured = True
        self.error = error

    async def search(self, query: str, *, media_kind: str, limit: int):
        if self.error:
            raise self.error
        return [
            CatalogMovie(
                catalog_id=f"{self.config.id}:1",
                provider_id=self.config.id,
                provider_name=self.config.name,
                source_id="1",
                title="星际穿越",
                year="2014",
                media_kind="movie",
            )
        ]


class _FakeCatalogRegistry:
    def __init__(self) -> None:
        self.values = [_FakeCatalogProvider("good"), _FakeCatalogProvider("bad", error=TimeoutError())]

    def list_available(self):
        return self.values


class CatalogServiceTests(IsolatedAsyncioTestCase):
    async def test_remember_merged_movie_for_every_source_alias(self) -> None:
        service = CatalogService(registry=_FakeCatalogRegistry())
        merged = CatalogMovie(
            catalog_id="douban:movie",
            provider_id="douban",
            provider_name="豆瓣",
            source_id="movie",
            title="星际穿越",
            overview="来自 TMDB 的完整简介。",
            sources=[
                CatalogSourceRef(provider_id="douban", provider_name="豆瓣", source_id="movie"),
                CatalogSourceRef(provider_id="tmdb", provider_name="TMDB", source_id="157336"),
            ],
        )

        service._remember([merged])

        self.assertEqual("来自 TMDB 的完整简介。", service._known_movies["douban:movie"].overview)
        self.assertEqual("来自 TMDB 的完整简介。", service._known_movies["tmdb:157336"].overview)

    async def test_one_catalog_failure_does_not_break_search(self) -> None:
        service = CatalogService(registry=_FakeCatalogRegistry())

        response = await service.search("星际穿越")

        self.assertEqual(1, len(response.items))
        self.assertEqual(1, sum(1 for trace in response.traces if trace.ok))
        self.assertEqual(1, sum(1 for trace in response.traces if not trace.ok))

    async def test_exact_title_first_and_missing_year_can_merge(self) -> None:
        high_priority = (
            [
                CatalogMovie(
                    catalog_id="douban:doc",
                    provider_id="douban",
                    provider_name="豆瓣",
                    source_id="doc",
                    title="《星际穿越》中的科学",
                    media_kind="movie",
                    rating=7.9,
                ),
                CatalogMovie(
                    catalog_id="douban:movie",
                    provider_id="douban",
                    provider_name="豆瓣",
                    source_id="movie",
                    title="星际穿越",
                    media_kind="movie",
                    rating=9.4,
                ),
            ],
            CatalogTrace(provider_id="douban", provider_name="豆瓣", ok=True, elapsed_ms=1),
        )
        lower_priority = (
            [
                CatalogMovie(
                    catalog_id="tmdb:157336",
                    provider_id="tmdb",
                    provider_name="TMDB",
                    source_id="157336",
                    title="星际穿越",
                    year="2014",
                    media_kind="movie",
                    overview="穿越星际寻找新的家园。",
                )
            ],
            CatalogTrace(provider_id="tmdb", provider_name="TMDB", ok=True, elapsed_ms=1),
        )

        response = CatalogService._merge([high_priority, lower_priority], 10, query="星际穿越")

        self.assertEqual("星际穿越", response.items[0].title)
        self.assertEqual("2014", response.items[0].year)
        self.assertEqual("穿越星际寻找新的家园。", response.items[0].overview)
        self.assertEqual(2, len(response.items))
