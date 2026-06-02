# services/agent/engine.py
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
        print("\n" + "="*50)
        print(f"[Agent 推理开始] 用户原始偏好:\n{user_preference_prompt}")
        print("="*50, flush=True)

        # 1. 升级版 System Prompt：强制 AI 动用搜索工具并优化关键词
        system_prompt = (
            "你是一个专业的影视专家。你的任务是分析用户的偏好，并决定使用哪个工具来获取候选电影列表。\n"
            "【关键规则】:\n"
            "1. 必须优先使用 `search_tmdb_movies` 工具。在 `query` 参数中填入用户偏好中最核心的关键词。\n"
            "2. 如果有多个类型（如爱情、科幻），请选择其中最主要的一个作为 query，不要把关键词堆砌在一起搜。\n"
            "3. 即使工具返回空结果，你也要继续思考或输出 JSON 报告，不要报错。\n"
            "请立即调用工具，不要回复任何解释。"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"我的偏好如下，请选择工具：\n{user_preference_prompt}"}
        ]

        # 2. 第一次呼叫 DeepSeek (工具选择阶段)
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
            "temperature": 0.2
        }

        import httpx
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, json=payload, headers=headers)
                response.raise_for_status()
                res_json = response.json()
        except Exception as e:
            print(f" [Agent 错误] 通信异常: {e}", flush=True)
            raise HTTPException(status_code=502, detail=f"Agent 路由通信失败: {str(e)}")

        choice_message = res_json["choices"][0]["message"]
        tool_calls = choice_message.get("tool_calls")
        executed_tool_data = []

        # 3. 工具执行层 - 修复：必须确保 tool_calls 被响应
        if tool_calls:
            for tool_call in tool_calls:
                function_name = tool_call["function"]["name"]
                function_args = json.loads(tool_call["function"]["arguments"])
                print(f" [Agent 决策成功] AI 选择了工具: {function_name}, 参数: {function_args}", flush=True)

                tool_function = AVAILABLE_TOOLS.get(function_name)
                # 无论搜索结果如何，都获取数据
                result_data = await tool_function(**function_args) if tool_function else []
                if result_data:
                    executed_tool_data.extend(result_data)

                # 【核心修复】必须向 messages 添加 tool 响应，否则 DeepSeek 会报错 400
                messages.append(choice_message)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": json.dumps(result_data, ensure_ascii=False)
                })
        else:
            print(" [Agent 决策异常] AI 没有选择工具，执行热门推荐兜底", flush=True)
            executed_tool_data = await AVAILABLE_TOOLS["fetch_tmdb_popular_movies"]()

        # 4. 第二阶段：生成推荐词 (如果搜出来是空的，则强行转热门兜底)
        if not executed_tool_data:
            print(" [Agent 搜索空结果] 强制触发热门电影数据...", flush=True)
            executed_tool_data = await AVAILABLE_TOOLS["fetch_tmdb_popular_movies"]()
            messages.append({"role": "system", "content": "刚才的搜索没结果，现在为你提供了一些当前的热门电影。"})

        final_system_prompt = (
            "你是一个资深影评家。请根据用户偏好和提供的电影数据，为每部电影写一段30-50字的推荐词。\n"
            "必须按 JSON 格式返回：{\"recommendations\": [{\"movie_id\": ID, \"reason\": \"...\"}]}"
        )

        messages[0] = {"role": "system", "content": final_system_prompt}
        messages.append({"role": "user", "content": "请输出针对性的推荐报告。"})

        ai_final_report = await agent_client.chat_completion(messages, json_mode=True)
        print(f" [Agent 推理完成] 已生成个性化推荐流。", flush=True)

        try:
            parsed_report = json.loads(ai_final_report)
            return {
                "raw_movies_context": executed_tool_data,
                "ai_reasons": parsed_report.get("recommendations", [])
            }
        except Exception:
            return {"raw_movies_context": executed_tool_data, "ai_reasons": []}

agent_engine = CineAgentEngine()
