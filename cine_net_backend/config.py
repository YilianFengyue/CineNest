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

    # 图片生成（OpenAI Images 兼容，gpt-image-2 @ api.gpt.ge）。
    # key 默认复用 llm_api_key；base 固定指向 gpt.ge 的图片站，无需额外 .env。
    # 若图片站与 LLM 不同供应商，再单独填 IMAGE_API_KEY。
    image_enabled: bool = True
    image_api_key: str = ""
    image_base_url: str = "https://api.gpt.ge/v1"
    image_model: str = "gpt-image-2"
    image_timeout_seconds: float = 120.0

    # TMDB 官方 API。优先使用 Read Access Token；也兼容 v3 API Key（TMDB_API_KEY）。
    tmdb_read_access_token: str = ""
    tmdb_api_key: str = ""
    tmdb_base_url: str = "https://api.themoviedb.org/3"
    tmdb_image_base: str = "https://image.tmdb.org/t/p/w500"
    tmdb_backdrop_base: str = "https://image.tmdb.org/t/p/w780"
    tmdb_proxy_url: str = "http://127.0.0.1:7890"

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
    local_video_dir: Path = BASE_DIR.parent / "LocalVideos"

    # 上传资产。图片可进入多模态模型；文件先持久化并预留 RAG。
    asset_dir: Path = BASE_DIR / "uploads"
    asset_max_bytes: int = 20 * 1024 * 1024
    asset_public_base_url: str = ""

    # AutoGLM 手机控制
    phone_enabled: bool = False
    phone_model_base_url: str = "https://open.bigmodel.cn/api/paas/v4"
    phone_model_name: str = "autoglm-phone"
    phone_api_key: str = ""
    phone_device_type: str = "adb"
    phone_device_id: str = ""
    phone_max_steps: int = 30
    phone_task_poll_interval_seconds: float = 0.2
    phone_console_enabled: bool = True
    static_phone_console_path: Path = BASE_DIR / "static" / "phone_console.html"

    # 服务
    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()
