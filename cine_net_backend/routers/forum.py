from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, Query

from db.database import get_conn
from models.schemas import (
    ForumComment,
    ForumCommentCreate,
    ForumLikeRequest,
    ForumLikeResponse,
    ForumPostCreate,
    ForumPostDetail,
    ForumPostDetailResponse,
    ForumPostList,
    ForumPostSummary,
)


router = APIRouter(prefix="/api/forum", tags=["forum"])


@router.get("/posts", response_model=ForumPostList)
async def list_forum_posts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    sort: str = Query("latest", pattern="^(latest|hot)$"),
    keyword: str = "",
    client_id: str = "",
) -> ForumPostList:
    where_sql = ""
    params: list[object] = []
    keyword = keyword.strip()
    if keyword:
        where_sql = "WHERE title LIKE ? OR content LIKE ? OR author_name LIKE ? OR movie_title LIKE ?"
        like = f"%{keyword}%"
        params.extend([like, like, like, like])

    order_sql = (
        "ORDER BY like_count DESC, comment_count DESC, created_at DESC"
        if sort == "hot"
        else "ORDER BY created_at DESC"
    )
    offset = (page - 1) * page_size

    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) AS total FROM forum_posts {where_sql}",
            params,
        ).fetchone()["total"]
        rows = conn.execute(
            f"""
            SELECT *
            FROM forum_posts
            {where_sql}
            {order_sql}
            LIMIT ? OFFSET ?
            """,
            [*params, page_size, offset],
        ).fetchall()
        liked_ids = _liked_post_ids(conn, client_id, [row["id"] for row in rows])

    return ForumPostList(
        items=[_summary_from_row(row, row["id"] in liked_ids) for row in rows],
        page=page,
        page_size=page_size,
        total=int(total),
    )


@router.post("/posts", response_model=ForumPostDetail)
async def create_forum_post(payload: ForumPostCreate) -> ForumPostDetail:
    title = payload.title.strip()
    content = payload.content.strip()
    author_name = payload.author_name.strip()
    client_id = payload.client_id.strip()
    if not title or not content or not author_name or not client_id:
        raise HTTPException(status_code=400, detail="Title, content, nickname and client_id are required.")

    post_id = uuid.uuid4().hex
    now = _now_text()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO forum_posts (
                id, title, content, author_name, client_id, movie_id, movie_title,
                image_url, sticker, like_count, comment_count, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)
            """,
            (
                post_id,
                title,
                content,
                author_name,
                client_id,
                payload.movie_id,
                (payload.movie_title or "").strip() or None,
                (payload.image_url or "").strip() or None,
                (payload.sticker or "").strip() or None,
                now,
                now,
            ),
        )
        row = _get_post_row(conn, post_id)
    return _detail_from_row(row, liked_by_me=False)


@router.get("/posts/{post_id}", response_model=ForumPostDetailResponse)
async def get_forum_post(post_id: str, client_id: str = "") -> ForumPostDetailResponse:
    with get_conn() as conn:
        row = _get_post_row(conn, post_id)
        liked = _is_liked(conn, post_id, client_id)
        comments = conn.execute(
            """
            SELECT id, post_id, content, author_name, created_at
            FROM forum_comments
            WHERE post_id = ?
            ORDER BY created_at ASC
            """,
            (post_id,),
        ).fetchall()
    return ForumPostDetailResponse(
        post=_detail_from_row(row, liked),
        comments=[ForumComment(**dict(comment)) for comment in comments],
    )


@router.post("/posts/{post_id}/like", response_model=ForumLikeResponse)
async def toggle_forum_like(post_id: str, payload: ForumLikeRequest) -> ForumLikeResponse:
    client_id = payload.client_id.strip()
    if not client_id:
        raise HTTPException(status_code=400, detail="client_id is required.")

    with get_conn() as conn:
        _get_post_row(conn, post_id)
        existing = conn.execute(
            "SELECT post_id FROM forum_likes WHERE post_id = ? AND client_id = ?",
            (post_id, client_id),
        ).fetchone()
        if existing:
            conn.execute(
                "DELETE FROM forum_likes WHERE post_id = ? AND client_id = ?",
                (post_id, client_id),
            )
            liked = False
        else:
            conn.execute(
                "INSERT INTO forum_likes (post_id, client_id, created_at) VALUES (?, ?, ?)",
                (post_id, client_id, _now_text()),
            )
            liked = True

        like_count = conn.execute(
            "SELECT COUNT(*) AS count FROM forum_likes WHERE post_id = ?",
            (post_id,),
        ).fetchone()["count"]
        conn.execute(
            "UPDATE forum_posts SET like_count = ?, updated_at = ? WHERE id = ?",
            (like_count, _now_text(), post_id),
        )
    return ForumLikeResponse(liked=liked, like_count=int(like_count))


@router.post("/posts/{post_id}/comments", response_model=ForumComment)
async def create_forum_comment(post_id: str, payload: ForumCommentCreate) -> ForumComment:
    content = payload.content.strip()
    author_name = payload.author_name.strip()
    client_id = payload.client_id.strip()
    if not content or not author_name or not client_id:
        raise HTTPException(status_code=400, detail="Comment, nickname and client_id are required.")

    comment_id = uuid.uuid4().hex
    now = _now_text()
    with get_conn() as conn:
        _get_post_row(conn, post_id)
        conn.execute(
            """
            INSERT INTO forum_comments (id, post_id, content, author_name, client_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (comment_id, post_id, content, author_name, client_id, now),
        )
        comment_count = conn.execute(
            "SELECT COUNT(*) AS count FROM forum_comments WHERE post_id = ?",
            (post_id,),
        ).fetchone()["count"]
        conn.execute(
            "UPDATE forum_posts SET comment_count = ?, updated_at = ? WHERE id = ?",
            (comment_count, now, post_id),
        )
        row = conn.execute(
            """
            SELECT id, post_id, content, author_name, created_at
            FROM forum_comments
            WHERE id = ?
            """,
            (comment_id,),
        ).fetchone()
    return ForumComment(**dict(row))


def _get_post_row(conn, post_id: str):
    row = conn.execute("SELECT * FROM forum_posts WHERE id = ?", (post_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Forum post not found.")
    return row


def _liked_post_ids(conn, client_id: str, post_ids: list[str]) -> set[str]:
    if not client_id or not post_ids:
        return set()
    placeholders = ",".join("?" for _ in post_ids)
    rows = conn.execute(
        f"""
        SELECT post_id
        FROM forum_likes
        WHERE client_id = ? AND post_id IN ({placeholders})
        """,
        [client_id, *post_ids],
    ).fetchall()
    return {str(row["post_id"]) for row in rows}


def _is_liked(conn, post_id: str, client_id: str) -> bool:
    if not client_id:
        return False
    return (
        conn.execute(
            "SELECT post_id FROM forum_likes WHERE post_id = ? AND client_id = ?",
            (post_id, client_id),
        ).fetchone()
        is not None
    )


def _summary_from_row(row, liked_by_me: bool) -> ForumPostSummary:
    content = str(row["content"] or "").strip()
    preview = content[:90] + ("..." if len(content) > 90 else "")
    return ForumPostSummary(
        id=row["id"],
        title=row["title"],
        content_preview=preview,
        author_name=row["author_name"],
        movie_id=row["movie_id"],
        movie_title=row["movie_title"],
        image_url=row["image_url"] if "image_url" in row.keys() else None,
        sticker=row["sticker"] if "sticker" in row.keys() else None,
        like_count=int(row["like_count"] or 0),
        comment_count=int(row["comment_count"] or 0),
        liked_by_me=liked_by_me,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _detail_from_row(row, liked_by_me: bool) -> ForumPostDetail:
    return ForumPostDetail(
        id=row["id"],
        title=row["title"],
        content=row["content"],
        author_name=row["author_name"],
        movie_id=row["movie_id"],
        movie_title=row["movie_title"],
        image_url=row["image_url"] if "image_url" in row.keys() else None,
        sticker=row["sticker"] if "sticker" in row.keys() else None,
        like_count=int(row["like_count"] or 0),
        comment_count=int(row["comment_count"] or 0),
        liked_by_me=liked_by_me,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _now_text() -> str:
    import datetime

    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
