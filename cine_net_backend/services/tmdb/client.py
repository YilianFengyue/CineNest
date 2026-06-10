# services/tmdb/client.py
#负责底层的异步网络请求，包含了超时、异常捕捉、API Key 注入以及自动指定中文语言（zh-CN）。
# services/tmdb/client.py
# services/tmdb/client.py
import httpx
from typing import Any, Dict
from fastapi import HTTPException
from config import settings


class TMDBHTTPClient:
    """TMDB 底层 HTTP 请求客户端"""

    def __init__(self) -> None:
        # 读取 .env 中配置的 Cloudflare Worker 专属加速域名
        self.base_url: str = settings.tmdb_base_url.rstrip("/")
        raw_token = str(settings.tmdb_api_key)
        # 强行清理 Token 首尾可能存在的换行符、空格、引号，防止请求头被损坏
        self.access_token: str = raw_token.strip().replace('"', '').replace("'", "")
        self.image_base: str = getattr(settings, "tmdb_image_base", "https://image.tmdb.org/t/p/w500").rstrip("/")
        self.proxy_url: str = str(getattr(settings, "tmdb_proxy_url", "") or "").strip()

    async def request(self, endpoint: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """封装底层的异步 GET 请求（显式拼接 URL，消除 GET Body 隐患）"""
        # 1. 构造标准的请求头（带上浏览器伪装）
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "accept": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"
        }

        # 2. 核心大招：不再把 params 丢给 httpx 去拼接，我们在代码里手动拼接
        # 这样可以 100% 保证发出去的是纯粹的、不带任何 Body 的标准 URL 请求
        query_str = "?language=zh-CN"
        if params:
            for k, v in params.items():
                if k != "language":  # 避免重复叠加 language
                    query_str += f"&{k}={v}"

        # 最终组合出来的完整请求 URL
        url = f"{self.base_url}{endpoint}{query_str}"

        try:
            # First try direct/env proxy. If the network blocks TMDB, retry with
            # the local proxy used by the Android/Gradle setup.
            try:
                async with httpx.AsyncClient(timeout=10.0, verify=False, trust_env=True) as client:
                    response = await client.get(url, headers=headers)
            except httpx.RequestError:
                if not self.proxy_url:
                    raise
                async with httpx.AsyncClient(
                    timeout=10.0,
                    verify=False,
                    trust_env=False,
                    proxy=self.proxy_url,
                ) as client:
                    response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as exc:
            status_code = exc.response.status_code
            detail = f"TMDB API 异常 (状态码 {status_code}): {exc.response.text}"
            raise HTTPException(status_code=status_code, detail=detail)
        except httpx.RequestError as exc:
            # 打印出最真实、最底层的错误名字
            raise HTTPException(status_code=503, detail=f"无法连接到 TMDB 服务器: {repr(exc)}")
