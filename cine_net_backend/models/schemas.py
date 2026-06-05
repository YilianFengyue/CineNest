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


class Post(BaseModel):
    movie: Movie
    recommend_reason: str = ""
    has_video_source: bool = False
    has_bilibili: bool = False
    poster_url: Optional[str] = None  # C 的 Micro Design 海报，空则前端回退 movie.poster_url


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


class UserPreference(BaseModel):
    liked_genres: list[str] = Field(default_factory=list)
    disliked_genres: list[str] = Field(default_factory=list)
    free_text: Optional[str] = None


class Feedback(BaseModel):
    movie_id: int
    liked: bool  # True=喜欢, False=不感兴趣
