# services/agent/engine.py
#第一次让大模型选择要调用的工具，
#代码执行工具后，第二次让大模型看着数据输出结构化的中文推荐理由
#这一层作为算力驱动，使用 DeepSeek 控制对话状态
import json
from typing import List, Dict, Any
from fastapi import HTTPException
from config import settings
from .client import agent_client
from .tools import AGENT_TOOLS_MANIFEST, AVAILABLE_TOOLS


class CineAgentEngine:
    """CineAgent 决策与推理核心引擎"""

    def __init__(self) -> None:
        self.tools = AGENT_TOOLS_MANIFEST

    async def run_recommendation_flow(self, user_preference_prompt: str) -> Dict[str, Any]:
        """
        Agent 推荐流核心：理解用户偏好 -> 自动选择并调用工具 -> 结合数据产出个性化结构化报告
        """
        # 1. 组装初始 System Prompt 引导模型做工具路由
        system_prompt = (
            "你是一个影视策展人。你的任务是根据用户的偏好口味，从可选工具中选择最合适的一个来获取候选电影数据。\n"
            "【注意】你只需要做出选择并调用工具，不要自行编造任何电影数据。"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"用户当前的看片偏好是：{user_preference_prompt}"}
        ]

        # 2. 第一次呼叫 DeepSeek，让模型判断调用哪个 Function
        url = f"{settings.deepseek_base_url.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.deepseek_api_key.strip()}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": getattr(settings, "llm_model", "deepseek-chat"),
            "messages": messages,
            "tools": self.tools,
            "tool_choice": "auto",
            "temperature": 0.1  # 严谨决策
        }

        # 这一步我们使用底层的原声异步请求，捕获 DeepSeek 的 tool_calls 意图
        import httpx
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, json=payload, headers=headers)
                response.raise_for_status()
                res_json = response.json()
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Agent 路由通信失败: {str(e)}")

        choice_message = res_json["choices"][0]["message"]
        tool_calls = choice_message.get("tool_calls")

        # 默认基础候选电影数据容器
        executed_tool_data = []

        # 3. 如果模型认为需要调用工具，则自动在后台执行
        if tool_calls:
            tool_call = tool_calls[0]
            function_name = tool_call["function"]["name"]
            function_args = json.loads(tool_call["function"]["arguments"])

            # 动态检索函数并异步等待执行
            tool_function = AVAILABLE_TOOLS.get(function_name)
            if tool_function:
                executed_tool_data = await tool_function(**function_args)
                # 将工具执行结果存入上下文，准备做第二阶段推理
                messages.append(choice_message)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": json.dumps(executed_tool_data, ensure_ascii=False)
                })
        else:
            # 兜底防御：大模型如果没选工具，我们强行喂给它默认的热门数据
            print(" [Agent Tool 警告] ──> 大模型未选工具，触发热门兜底")
            executed_tool_data = await AVAILABLE_TOOLS["fetch_tmdb_popular_movies"]()

        # 4. 第二阶段：让大模型看着拿回来的电影数据，用中文撰写直击痛点的推荐词
        final_system_prompt = (
            "你是一个殿堂级的电影骨灰级评论家。\n"
            "请根据用户提供的偏好，结合当前刚才获取到的真实电影列表数据，为列表中的每部电影撰写一句极具诱惑力、一针见血的个性化深度推荐词。\n"
            "【硬性验收标准】返回的推荐语必须读起来像资深影迷写的自然语言，严禁使用任何固定套路模板！\n"
            "你必须使用标准的 JSON 格式返回，不要包含任何 markdown 标记。格式严格限制如下：\n"
            '{"recommendations": [{"movie_id": 电影ID, "reason": "30-50字的硬核影评推荐词"}]}'
        )

        # 替换系统提示词，聚焦于精美内容输出
        messages[0] = {"role": "system", "content": final_system_prompt}
        messages.append({"role": "user", "content": "请针对刚才拿到的电影数据，结合我的口味开始策展并输出 JSON 报告。"})

        # 使用之前解耦好的底层客户端进行 JSON 模式读取
        ai_final_report = await agent_client.chat_completion(messages, json_mode=True)

        try:
            parsed_report = json.loads(ai_final_report)
            return {
                "raw_movies_context": executed_tool_data,  # 原始数据上下文
                "ai_reasons": parsed_report.get("recommendations", [])  # 智能生成的推荐理由
            }
        except Exception:
            return {"raw_movies_context": executed_tool_data, "ai_reasons": []}


agent_engine = CineAgentEngine()