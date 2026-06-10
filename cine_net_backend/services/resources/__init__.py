"""影视资源聚合层：配置化 Provider、并发检索与播放列表解析。"""

from .aggregator import ResourceAggregator, get_resource_aggregator

__all__ = ["ResourceAggregator", "get_resource_aggregator"]
