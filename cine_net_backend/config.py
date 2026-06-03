"""全局配置。从 .env 读取，业务代码不绑定具体模型供应商。"""
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # OpenAI Chat Completions 兼容模型。可接聚合站，不写死供应商。
    llm_api_key: str = ""
    llm_base_url: str = "https://api.openai.com/v1"
    llm_model: str = ""
    llm_model_fast: str = ""
    llm_model_deep: str = ""
    llm_temperature: float = 0.2
    llm_timeout_seconds: float = 90.0
    llm_max_retries: int = 2

    # TMDB 官方 API Read Access Token。Step 1 的播放资源检索不依赖 TMDB。
    tmdb_read_access_token: str = ""
    tmdb_base_url: str = "https://api.themoviedb.org/3"
    tmdb_image_base: str = "https://image.tmdb.org/t/p/w500"
    tmdb_backdrop_base: str = "https://image.tmdb.org/t/p/w780"

    # MacCMS 聚合资源层
    resource_provider_config: Path = BASE_DIR / "services" / "resources" / "providers.yaml"
    resource_request_timeout_seconds: float = 6.0
    resource_max_concurrency: int = 10
    resource_search_limit_per_provider: int = 5

    # 影视资料 Catalog。豆瓣可直接使用；TMDB 填 Token 后启用。
    catalog_provider_config: Path = BASE_DIR / "services" / "catalog" / "providers.yaml"
    catalog_request_timeout_seconds: float = 10.0
    catalog_cache_ttl_seconds: int = 1800
    recommendation_cache_ttl_seconds: int = 300

    # SQLite 持久化。后续可替换 PostgreSQL，不影响 API 契约。
    database_path: Path = BASE_DIR / "db" / "cinenest.db"
    agent_checkpoint_db_path: Path = BASE_DIR / "db" / "agent_checkpoints.sqlite"

    # 上传资产。图片可进入多模态模型；文件先持久化并预留 RAG。
    asset_dir: Path = BASE_DIR / "uploads"
    asset_max_bytes: int = 20 * 1024 * 1024
    asset_public_base_url: str = ""

    # 服务
    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()
