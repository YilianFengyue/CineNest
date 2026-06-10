"""CineNest 后端 SQLite 存储。"""
from __future__ import annotations

import datetime
import json
import sqlite3

from config import settings
from models.schemas import CollectionItem, UserPreference, WatchHistoryItem


def get_conn() -> sqlite3.Connection:
    settings.database_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.database_path, timeout=10)
    # Some Windows development environments lock SQLite rollback journal files.
    # The app only stores local course-demo state, so disabling the journal keeps
    # preferences/history usable instead of failing every request with disk I/O.
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """初始化课设所需的轻量表。"""

    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS preferences (
                id INTEGER PRIMARY KEY,
                liked_genres TEXT,
                disliked_genres TEXT,
                free_text TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                model TEXT NOT NULL DEFAULT 'default',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '',
                attachments_json TEXT NOT NULL DEFAULT '[]',
                tool_calls_json TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_chat_messages_session_time ON chat_messages(session_id, created_at)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                filename TEXT NOT NULL,
                stored_name TEXT NOT NULL,
                mime TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS recommendation_posts (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                media_kind TEXT NOT NULL,
                title TEXT NOT NULL,
                catalog_provider_id TEXT NOT NULL DEFAULT '',
                catalog_source_id TEXT NOT NULL DEFAULT '',
                resource_provider_id TEXT NOT NULL DEFAULT '',
                resource_remote_id TEXT NOT NULL DEFAULT '',
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_recommendation_posts_query ON recommendation_posts(query, expires_at)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS news_items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                source TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                published_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS news_tasks (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                media_kind TEXT NOT NULL DEFAULT 'movie',
                status TEXT NOT NULL,
                stage TEXT NOT NULL,
                news_id TEXT NOT NULL DEFAULT '',
                error TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                finished_at TEXT NOT NULL DEFAULT ''
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_news_tasks_updated ON news_tasks(updated_at DESC)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS watch_history (
                movie_id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                visited_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS collections (
                movie_id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                poster_url TEXT,
                collected_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS taste_dna_avatars (
                signature TEXT PRIMARY KEY,
                avatar_url TEXT NOT NULL,
                prompt TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS forum_posts (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                author_name TEXT NOT NULL,
                client_id TEXT NOT NULL,
                movie_id INTEGER,
                movie_title TEXT,
                image_url TEXT,
                sticker TEXT,
                like_count INTEGER NOT NULL DEFAULT 0,
                comment_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        _ensure_column(conn, "forum_posts", "image_url", "TEXT")
        _ensure_column(conn, "forum_posts", "sticker", "TEXT")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_forum_posts_created ON forum_posts(created_at DESC)"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_forum_posts_hot ON forum_posts(like_count DESC, comment_count DESC, created_at DESC)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS forum_comments (
                id TEXT PRIMARY KEY,
                post_id TEXT NOT NULL,
                content TEXT NOT NULL,
                author_name TEXT NOT NULL,
                client_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(post_id) REFERENCES forum_posts(id) ON DELETE CASCADE
            )
            """
        )
        _seed_forum_defaults_v2(conn)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_forum_comments_post ON forum_comments(post_id, created_at)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS forum_likes (
                post_id TEXT NOT NULL,
                client_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY(post_id, client_id),
                FOREIGN KEY(post_id) REFERENCES forum_posts(id) ON DELETE CASCADE
            )
            """
        )


def _empty_preference() -> UserPreference:
    return UserPreference(liked_genres=[], disliked_genres=[], free_text="")


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, column_type: str) -> None:
    columns = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in columns:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {column_type}")


def _seed_forum_defaults(conn: sqlite3.Connection) -> None:
    existing = conn.execute(
        "SELECT id FROM forum_posts WHERE client_id = 'cinenest-seed' LIMIT 1"
    ).fetchone()
    if existing is not None:
        return
    posts = [
        (
            "seed-cozy-cat",
            "今晚的观影搭子是一只爆米花小猫",
            "刚刚重温《千与千寻》，突然觉得电影最神奇的地方是：明明坐在宿舍里，却能被一阵风吹到另一个世界。\n\n给大家递一桶云朵爆米花，今晚你们想看治愈系、脑洞系，还是那种看完想发呆十分钟的片子？",
            "放映厅小橘",
            129,
            "Spirited Away",
            "asset:pinterest1.png",
            "🍿🐱✨",
            18,
            3,
            "2026-06-09 09:12:00",
        ),
        (
            "seed-sci-fi",
            "科幻片里的机器人为什么总是那么可爱",
            "我发现一个规律：只要机器人拥有圆圆的眼睛和一点点笨拙感，我就会立刻投降。\n\n《机器人总动员》那种孤独又温柔的气质，真的很适合雨天看。大家心中最萌的银幕机器人是谁？",
            "银河检票员",
            None,
            "Sci-Fi Robots",
            "asset:pinterest2.png",
            "🤖💫🛸",
            25,
            4,
            "2026-06-09 09:20:00",
        ),
        (
            "seed-comedy",
            "喜剧片救命清单：不开心时请打开",
            "提名一个片单玩法：每个人贡献一部“心情急救喜剧”。\n\n我的选择是那种前十分钟就能让人笑出声的电影，最好还有一点点荒诞、一点点温柔，以及很多很多无厘头。",
            "快乐剪票口",
            None,
            "Comedy Rescue List",
            "",
            "😆🎬🍧",
            12,
            2,
            "2026-06-09 09:28:00",
        ),
        (
            "seed-midnight",
            "深夜悬疑片规则：灯可以关，但零食不能停",
            "昨天看悬疑片看到一半，宿舍灯突然闪了一下。我的第一反应不是害怕，而是赶紧护住薯片。\n\n大家有没有那种“吓得不敢暂停，但又忍不住继续看”的电影？求推荐，胆小但爱看。",
            "午夜薯片守护者",
            None,
            "Mystery Night",
            "",
            "🌙🕵️‍♀️🥔",
            16,
            3,
            "2026-06-09 09:36:00",
        ),
    ]
    for post in posts:
        conn.execute(
            """
            INSERT INTO forum_posts (
                id, title, content, author_name, client_id, movie_id, movie_title,
                image_url, sticker, like_count, comment_count, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, 'cinenest-seed', ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (*post, post[-1]),
        )
    comments = [
        ("seed-c1", "seed-cozy-cat", "我投治愈系！这种帖子看着就像被毛毯包起来。", "棉花糖影迷", "2026-06-09 09:14:00"),
        ("seed-c2", "seed-cozy-cat", "云朵爆米花这个说法太可爱了，已截图。", "截图收藏家", "2026-06-09 09:16:00"),
        ("seed-c3", "seed-sci-fi", "最萌机器人必须有 WALL·E，一双眼睛赢了。", "废土浪漫派", "2026-06-09 09:22:00"),
        ("seed-c4", "seed-comedy", "推荐《三傻大闹宝莱坞》，笑完还很热血。", "片单搬运工", "2026-06-09 09:30:00"),
        ("seed-c5", "seed-midnight", "胆小但爱看，这不就是我本人吗。", "被窝侦探", "2026-06-09 09:39:00"),
    ]
    for comment in comments:
        conn.execute(
            """
            INSERT INTO forum_comments (id, post_id, content, author_name, client_id, created_at)
            VALUES (?, ?, ?, ?, 'cinenest-seed', ?)
            """,
            comment,
        )
    for post_id in {comment[1] for comment in comments}:
        count = conn.execute(
            "SELECT COUNT(*) AS count FROM forum_comments WHERE post_id = ?",
            (post_id,),
        ).fetchone()["count"]
        conn.execute(
            "UPDATE forum_posts SET comment_count = ? WHERE id = ?",
            (count, post_id),
        )


def _seed_forum_defaults_v2(conn: sqlite3.Connection) -> None:
    nine_grid = "|".join(
        [
            "asset:pinterest1.png",
            "asset:pinterest2.png",
            "asset:pinterest1.png",
            "asset:pinterest2.png",
            "asset:pinterest1.png",
            "asset:pinterest2.png",
            "asset:pinterest1.png",
            "asset:pinterest2.png",
            "asset:pinterest1.png",
        ]
    )
    posts = [
        (
            "seed-cozy-cat",
            "今晚的观影搭子是一只爆米花小猫",
            "刚刚重温《千与千寻》，突然觉得电影最神奇的地方是：明明坐在宿舍里，却能被一阵风吹到另一个世界。\n\n给大家递一桶云朵爆米花，今晚你们想看治愈系、脑洞系，还是那种看完想发呆十分钟的片子？",
            "放映厅小橘",
            129,
            "Spirited Away",
            "asset:pinterest1.png",
            "🍿🐱✨",
            18,
            "2026-06-09 09:12:00",
        ),
        (
            "seed-sci-fi",
            "科幻片里的机器人为什么总是那么可爱",
            "我发现一个规律：只要机器人拥有圆圆的眼睛和一点点笨拙感，我就会立刻投降。\n\n《机器人总动员》那种孤独又温柔的气质，真的很适合雨天看。大家心中最萌的银幕机器人是谁？",
            "银河检票员",
            None,
            "Sci-Fi Robots",
            "asset:pinterest2.png",
            "🤖💫🛸",
            25,
            "2026-06-09 09:20:00",
        ),
        (
            "seed-comedy",
            "喜剧片救命清单：不开心时请打开",
            "提名一个片单玩法：每个人贡献一部“心情急救喜剧”。\n\n我的选择是那种前十分钟就能让人笑出声的电影，最好还有一点点荒诞、一点点温柔，以及很多很多无厘头。",
            "快乐剪票口",
            None,
            "Comedy Rescue List",
            "",
            "😆🎬🍧",
            12,
            "2026-06-09 09:28:00",
        ),
        (
            "seed-midnight",
            "深夜悬疑片规则：灯可以关，但零食不能停",
            "昨天看悬疑片看到一半，宿舍灯突然闪了一下。我的第一反应不是害怕，而是赶紧护住薯片。\n\n大家有没有那种“吓得不敢暂停，但又忍不住继续看”的电影？求推荐，胆小但爱看。",
            "午夜薯片守护者",
            None,
            "Mystery Night",
            "",
            "🌙🕵️‍♀️🥔",
            16,
            "2026-06-09 09:36:00",
        ),
        (
            "seed-nine-grid-cute",
            "交出你相册里最适合电影社区的九宫格",
            "今天的主题是：把可爱、脑洞、电影感全部塞进九宫格。\n\n我先发一组“观影搭子宇宙”：左边是爆米花小队，右边是银河放映厅，中间那张负责卖萌。评论区请交出你们的可爱表情包库存！",
            "九宫格放映机",
            None,
            "Cute Movie Moodboard",
            nine_grid,
            "🐾🍿🎞️🌟",
            36,
            "2026-06-09 09:44:00",
        ),
    ]
    for post in posts:
        conn.execute(
            """
            INSERT OR IGNORE INTO forum_posts (
                id, title, content, author_name, client_id, movie_id, movie_title,
                image_url, sticker, like_count, comment_count, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, 'cinenest-seed', ?, ?, ?, ?, ?, 0, ?, ?)
            """,
            (*post, post[-1]),
        )
        conn.execute(
            """
            UPDATE forum_posts
            SET title = ?,
                content = ?,
                author_name = ?,
                movie_id = ?,
                movie_title = ?,
                image_url = ?,
                sticker = ?,
                like_count = max(like_count, ?),
                updated_at = ?
            WHERE id = ? AND client_id = 'cinenest-seed'
            """,
            (
                post[1],
                post[2],
                post[3],
                post[4],
                post[5],
                post[6],
                post[7],
                post[8],
                post[9],
                post[0],
            ),
        )

    comments = [
        ("seed-c1", "seed-cozy-cat", "我投治愈系！这种帖子看着就像被毛毯包起来。", "棉花糖影迷", "2026-06-09 09:14:00"),
        ("seed-c2", "seed-cozy-cat", "云朵爆米花这个说法太可爱了，已截图收藏。", "截图收藏家", "2026-06-09 09:16:00"),
        ("seed-c3", "seed-cozy-cat", "想看那种看完会相信世界偷偷发光的电影。", "小夜灯同学", "2026-06-09 09:18:00"),
        ("seed-c4", "seed-sci-fi", "最萌机器人必须有 WALL·E，一双眼睛赢了。", "废土浪漫派", "2026-06-09 09:22:00"),
        ("seed-c5", "seed-sci-fi", "机器人一歪头，我的防线就没了。", "机械心软软", "2026-06-09 09:23:00"),
        ("seed-c6", "seed-sci-fi", "雨天加科幻片真的绝配，像宇宙在窗外打盹。", "雨滴观测员", "2026-06-09 09:25:00"),
        ("seed-c7", "seed-comedy", "推荐《三傻大闹宝莱坞》，笑完还很热血。", "片单搬运工", "2026-06-09 09:30:00"),
        ("seed-c8", "seed-comedy", "我需要这个清单续命，期末周请多来一点。", "快乐电量1%", "2026-06-09 09:31:00"),
        ("seed-c9", "seed-comedy", "荒诞但温柔，这五个字已经把我拿捏了。", "喜剧补给站", "2026-06-09 09:33:00"),
        ("seed-c10", "seed-midnight", "胆小但爱看，这不就是我本人吗。", "被窝侦探", "2026-06-09 09:39:00"),
        ("seed-c11", "seed-midnight", "我看悬疑片必须开弹幕，不然不敢呼吸。", "弹幕护体", "2026-06-09 09:40:00"),
        ("seed-c12", "seed-midnight", "薯片不能停太真实了，咔嚓声就是我的安全感。", "薯片守夜人", "2026-06-09 09:41:00"),
        ("seed-c13", "seed-nine-grid-cute", "这个九宫格好像电影节限定贴纸，萌得很正式。", "贴纸收集员", "2026-06-09 09:45:00"),
        ("seed-c14", "seed-nine-grid-cute", "中间那张负责卖萌，我负责疯狂点赞。", "爆米花小队长", "2026-06-09 09:46:00"),
        ("seed-c15", "seed-nine-grid-cute", "建议开一个“可爱电影截图交换大会”。", "截图交换生", "2026-06-09 09:47:00"),
        ("seed-c16", "seed-nine-grid-cute", "九宫格一出来，社区终于有热闹的样子了。", "路过的检票员", "2026-06-09 09:48:00"),
        ("seed-c17", "seed-nine-grid-cute", "我宣布这组图适合配一首轻快片尾曲。", "片尾曲观察员", "2026-06-09 09:49:00"),
    ]
    for comment in comments:
        conn.execute(
            """
            INSERT OR IGNORE INTO forum_comments (
                id, post_id, content, author_name, client_id, created_at
            )
            VALUES (?, ?, ?, ?, 'cinenest-seed', ?)
            """,
            comment,
        )

    conn.execute(
        """
        UPDATE forum_posts
        SET comment_count = (
            SELECT COUNT(*)
            FROM forum_comments
            WHERE forum_comments.post_id = forum_posts.id
        )
        """
    )


def _json_list(value: str | None) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return []
    return [str(item) for item in data] if isinstance(data, list) else []


def _now_text() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def save_user_preference(pref: UserPreference) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO preferences (id, liked_genres, disliked_genres, free_text)
            VALUES (1, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                liked_genres = excluded.liked_genres,
                disliked_genres = excluded.disliked_genres,
                free_text = excluded.free_text
            """,
            (
                json.dumps(pref.liked_genres, ensure_ascii=False),
                json.dumps(pref.disliked_genres, ensure_ascii=False),
                pref.free_text or "",
            ),
        )


def get_user_preference() -> UserPreference:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT liked_genres, disliked_genres, free_text FROM preferences WHERE id = 1"
        ).fetchone()
    if row is None:
        return _empty_preference()
    return UserPreference(
        liked_genres=_json_list(row["liked_genres"]),
        disliked_genres=_json_list(row["disliked_genres"]),
        free_text=row["free_text"] or "",
    )


def add_watch_history(movie_id: int, title: str) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO watch_history (movie_id, title, visited_at)
            VALUES (?, ?, ?)
            ON CONFLICT(movie_id) DO UPDATE SET
                title = excluded.title,
                visited_at = excluded.visited_at
            """,
            (movie_id, title, _now_text()),
        )


def get_watch_history_titles() -> list[str]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT title FROM watch_history ORDER BY visited_at DESC LIMIT 10"
        ).fetchall()
    return [str(row["title"]) for row in rows if row["title"]]


def get_watch_history() -> list[WatchHistoryItem]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT movie_id, title, visited_at
            FROM watch_history
            ORDER BY visited_at DESC
            LIMIT 50
            """
        ).fetchall()
    return [WatchHistoryItem(**dict(row)) for row in rows]


def toggle_collection(movie_id: int, title: str, poster_url: str | None = None) -> bool:
    """切换收藏状态。返回 True 表示现在已收藏，False 表示已取消收藏。"""

    with get_conn() as conn:
        existing = conn.execute(
            "SELECT movie_id FROM collections WHERE movie_id = ?",
            (movie_id,),
        ).fetchone()
        if existing is not None:
            conn.execute("DELETE FROM collections WHERE movie_id = ?", (movie_id,))
            return False
        conn.execute(
            """
            INSERT INTO collections (movie_id, title, poster_url, collected_at)
            VALUES (?, ?, ?, ?)
            """,
            (movie_id, title, poster_url, _now_text()),
        )
        return True


def get_collections() -> list[CollectionItem]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT movie_id, title, poster_url, collected_at
            FROM collections
            ORDER BY collected_at DESC
            """
        ).fetchall()
    return [CollectionItem(**dict(row)) for row in rows]


def is_movie_collected(movie_id: int) -> bool:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT movie_id FROM collections WHERE movie_id = ?",
            (movie_id,),
        ).fetchone()
    return row is not None


def get_taste_avatar(signature: str) -> dict[str, str] | None:
    with get_conn() as conn:
        row = conn.execute(
            """
            SELECT signature, avatar_url, prompt, created_at
            FROM taste_dna_avatars
            WHERE signature = ?
            """,
            (signature,),
        ).fetchone()
    return dict(row) if row is not None else None


def save_taste_avatar(signature: str, avatar_url: str, prompt: str) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO taste_dna_avatars (signature, avatar_url, prompt, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(signature) DO UPDATE SET
                avatar_url = excluded.avatar_url,
                prompt = excluded.prompt,
                created_at = excluded.created_at
            """,
            (signature, avatar_url, prompt, _now_text()),
        )
