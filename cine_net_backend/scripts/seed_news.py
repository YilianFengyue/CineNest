"""写入资讯页演示用种子数据。

用法：
    cd cine_net_backend
    python scripts/seed_news.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from db import init_db
from services.news import seed_news_items


def main() -> None:
    init_db()
    items = seed_news_items()
    print(f"seeded {len(items)} news items")
    for item in items:
        print(f"- {item.id}: {item.title}")


if __name__ == "__main__":
    main()
