"""共享数据模型（共建）。字段需与 Flutter 端 lib/models/ 严格对齐。

对应关系：
  Movie          ↔ app/lib/models/movie.dart
  Post           ↔ app/lib/models/post.dart
  VideoSource    ↔ app/lib/models/video_source.dart
  UserPreference ↔ app/lib/models/user_preference.dart
"""
from typing import Optional
from pydantic import BaseModel, Field


class Movie(BaseModel):
    id: int
    title: str
    original_title: Optional[str] = None
    year: Optional[int] = None
    genres: list[str] = Field(default_factory=list)
    rating: Optional[float] = None
    overview: Optional[str] = None
    poster_url: Optional[str] = None
    backdrop_url: Optional[str] = None
    directors: list[str] = Field(default_factory=list)
    cast: list[str] = Field(default_factory=list)
    is_collected: bool = False


class Post(BaseModel):
    movie: Movie
    recommend_reason: str = ""
    has_video_source: bool = False
    has_bilibili: bool = False
    poster_url: Optional[str] = None  # C 的 Micro Design 海报，空则前端回退 movie.poster_url
    debug_info: Optional[str] = None


class ScenarioResponse(BaseModel):
    posts: list[Post]
    debug_info: Optional[str] = None


class VideoEpisode(BaseModel):
    index: int
    title: str
    play_url: str


class VideoSource(BaseModel):
    id: str
    name: str
    quality: Optional[str] = None
    type: str = "web"  # web | bilibili | netdisk
    play_url: Optional[str] = None
    cover: Optional[str] = None
    play_count: Optional[int] = None
    episodes: list[VideoEpisode] = Field(default_factory=list)


class LocalVideo(BaseModel):
    id: str
    title: str
    filename: str
    relative_path: str
    size: int
    modified_at: str
    stream_url: str


class UserPreference(BaseModel):
    liked_genres: list[str] = Field(default_factory=list)
    disliked_genres: list[str] = Field(default_factory=list)
    free_text: Optional[str] = None


class Feedback(BaseModel):
    movie_id: int
    liked: bool  # True=喜欢, False=不感兴趣


class WatchHistoryItem(BaseModel):
    movie_id: int
    title: str
    visited_at: str


class WatchHistoryRequest(BaseModel):
    movie_id: int
    title: str


class CollectionItem(BaseModel):
    movie_id: int
    title: str
    poster_url: Optional[str] = None
    collected_at: str


class CollectionToggleRequest(BaseModel):
    movie_id: int
    title: str
    poster_url: Optional[str] = None


class TasteScore(BaseModel):
    name: str
    score: float


class TasteDNA(BaseModel):
    top_genres: list[TasteScore] = Field(default_factory=list)
    avoid_genres: list[str] = Field(default_factory=list)
    mood_tags: list[str] = Field(default_factory=list)
    era_tags: list[str] = Field(default_factory=list)
    summary: str
    confidence: float
    avatar_url: Optional[str] = None
    signature: str


class TasteAvatarResponse(BaseModel):
    avatar_url: str
    prompt: str
    cached: bool
    signature: str
    warning: Optional[str] = None


class ForumPostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    content: str = Field(min_length=1, max_length=2000)
    author_name: str = Field(min_length=1, max_length=24)
    client_id: str = Field(min_length=4, max_length=80)
    movie_id: Optional[int] = None
    movie_title: Optional[str] = None
    image_url: Optional[str] = None
    sticker: Optional[str] = None


class ForumCommentCreate(BaseModel):
    content: str = Field(min_length=1, max_length=800)
    author_name: str = Field(min_length=1, max_length=24)
    client_id: str = Field(min_length=4, max_length=80)


class ForumLikeRequest(BaseModel):
    client_id: str = Field(min_length=4, max_length=80)


class ForumPostSummary(BaseModel):
    id: str
    title: str
    content_preview: str
    author_name: str
    like_count: int
    comment_count: int
    liked_by_me: bool
    created_at: str
    updated_at: str
    movie_id: Optional[int] = None
    movie_title: Optional[str] = None
    image_url: Optional[str] = None
    sticker: Optional[str] = None


class ForumComment(BaseModel):
    id: str
    post_id: str
    content: str
    author_name: str
    created_at: str


class ForumPostDetail(BaseModel):
    id: str
    title: str
    content: str
    author_name: str
    like_count: int
    comment_count: int
    liked_by_me: bool
    created_at: str
    updated_at: str
    movie_id: Optional[int] = None
    movie_title: Optional[str] = None
    image_url: Optional[str] = None
    sticker: Optional[str] = None


class ForumPostList(BaseModel):
    items: list[ForumPostSummary] = Field(default_factory=list)
    page: int
    page_size: int
    total: int


class ForumPostDetailResponse(BaseModel):
    post: ForumPostDetail
    comments: list[ForumComment] = Field(default_factory=list)


class ForumLikeResponse(BaseModel):
    liked: bool
    like_count: int


class GraphNode(BaseModel):
    id: str
    label: str
    type: str  # movie | person | genre | keyword
    movie_id: Optional[int] = None  # 仅当 type 为 movie 时存在


class GraphLink(BaseModel):
    source: str
    target: str
    relation: str


class MovieGraphResponse(BaseModel):
    nodes: list[GraphNode]
    links: list[GraphLink]
