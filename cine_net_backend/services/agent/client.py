# services/agent/client.py
import httpx
import json
from typing import List, Dict, Any
from fastapi import HTTPException
from config import settings


class DeepSeekAgentClient:
    """DeepSeek 大模型智能体底层驱动"""

    def __init__(self) -> None:
        self.api_key: str = settings.deepseek_api_key.strip()
        self.base_url: str = settings.deepseek_base_url.rstrip("/")
        self.model: str = getattr(settings, "llm_model", "deepseek-chat")

    async def chat_completion(self, messages: List[Dict[str, str]], json_mode: bool = False) -> str:
        """调用 DeepSeek 对话接口"""
        url = f"{self.base_url}/chat/completions"

        # 确保 Authorization 格式正确
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.2,  # 低温度系数保证推荐逻辑的逻辑严密性
        }

        # 如果开启了 JSON Mode (DeepSeek 完美支持)
        if json_mode:
            payload["response_format"] = {"type": "json_object"}

        try:
            # 大模型思考可能需要较长时间，timeout 设长一点（60秒）
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(url, json=payload, headers=headers)
                response.raise_for_status()
                result = response.json()
                return result["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as exc:
            raise HTTPException(status_code=exc.response.status_code, detail=f"DeepSeek API 异常: {exc.response.text}")
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"无法连接到 DeepSeek 智能体: {str(e)}")


# 实例化全局单例
agent_client = DeepSeekAgentClient()