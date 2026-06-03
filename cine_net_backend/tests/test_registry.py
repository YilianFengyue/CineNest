from unittest import TestCase

from services.resources.registry import ProviderRegistry


class ProviderRegistryTests(TestCase):
    def test_load_twenty_configured_providers(self) -> None:
        registry = ProviderRegistry()

        self.assertEqual(24, len(registry.list_all()))
        self.assertEqual(20, len(registry.list_enabled()))
        self.assertEqual("无尽资源", registry.get("wujin").config.name)
