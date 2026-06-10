"""AI 图片生成服务（OpenAI Images 兼容，如 gpt-image-2）。"""

from .service import generate_image, is_image_enabled, movie_image_prompt

__all__ = ["generate_image", "is_image_enabled", "movie_image_prompt"]
