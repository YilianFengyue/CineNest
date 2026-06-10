from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase

from services.resources.aggregator import ResourceAggregator
from services.resources.models import ResourceCandidate


class _FakeProvider:
    def __init__(self, provider_id: str, *, error: Exception | None = None) -> None:
        self.config = SimpleNamespace(id=provider_id, name=provider_id, enabled=True)
        self.error = error

    async def search(self, keyword: str, *, limit: int):
        if self.error:
            raise self.error
        return [
            ResourceCandidate(
                provider_id=self.config.id,
                provider_name=self.config.name,
                remote_id=f"{self.config.id}-1",
                title="星际穿越",
                category="科幻片",
                cover_url="https://img.example/interstellar.jpg",
                remarks="HD",
            )
        ]


class _FakeRegistry:
    def __init__(self) -> None:
        self.providers = [_FakeProvider("good-a"), _FakeProvider("bad", error=TimeoutError()), _FakeProvider("good-b")]

    def list_enabled(self):
        return self.providers


class ResourceAggregatorTests(IsolatedAsyncioTestCase):
    async def test_one_provider_failure_does_not_break_search(self) -> None:
        aggregator = ResourceAggregator(registry=_FakeRegistry())

        response = await aggregator.search("星际穿越")

        self.assertEqual(1, len(response.items))
        self.assertEqual(2, len(response.items[0].sources))
        self.assertEqual(2, sum(1 for trace in response.traces if trace.ok))
        self.assertEqual(1, sum(1 for trace in response.traces if not trace.ok))
