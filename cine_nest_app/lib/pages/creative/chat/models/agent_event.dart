import 'dart:convert';

/// 后端 Agent WebSocket 事件类型（对应 `services/agent/schemas.py` 的 `AgentStreamEvent.type`）。
///
/// 真实验收过的事件顺序：started → tool_started → tool_finished → attachment → delta → done。
enum AgentEventType {
  started, // 开始处理，显示「正在思考」
  delta, // 追加 Agent 文本（当前后端是分段全量，非逐 token）
  toolStarted, // Agent 调起某工具，UI 显示来源 chip
  toolFinished, // 工具返回，调试用，正式 UI 多忽略内容
  attachment, // 结构化附件（推荐 feed / 互动海报），渲染成卡片
  done, // 流结束，关加载
  error, // 出错，显示提示 + 重试
  unknown;

  static AgentEventType parse(String? raw) {
    switch (raw) {
      case 'started':
        return AgentEventType.started;
      case 'delta':
        return AgentEventType.delta;
      case 'tool_started':
        return AgentEventType.toolStarted;
      case 'tool_finished':
        return AgentEventType.toolFinished;
      case 'attachment':
        return AgentEventType.attachment;
      case 'done':
        return AgentEventType.done;
      case 'error':
        return AgentEventType.error;
      default:
        return AgentEventType.unknown;
    }
  }
}

/// 一帧 Agent 流式事件。
///
/// 后端帧结构：`{type, thread_id, content, data}`。
///   · `delta` / `error`：文本在 [content]。
///   · `tool_started`：[data] 是工具调用（`{name, args, id, type}`）。
///   · `tool_finished`：[data] 为 `{tool_name, content}`。
///   · `attachment`：[data] 为 `{type, schema_version, payload}`。
class AgentEvent {
  final AgentEventType type;
  final String threadId;
  final String content;
  final Map<String, dynamic> data;

  const AgentEvent({
    required this.type,
    this.threadId = '',
    this.content = '',
    this.data = const {},
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) => AgentEvent(
    type: AgentEventType.parse(json['type'] as String?),
    threadId: json['thread_id'] as String? ?? '',
    content: json['content'] as String? ?? '',
    data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  /// 从原始 WebSocket 文本帧解析；非法 JSON 返回 [AgentEventType.unknown]。
  static AgentEvent? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AgentEvent.fromJson(decoded);
      if (decoded is Map) {
        return AgentEvent.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  // ── tool_started 便捷取值 ──
  /// 工具名（tool_started 用 `name`，tool_finished 用 `tool_name`）。
  String get toolName =>
      (data['name'] ?? data['tool_name'] ?? '').toString();

  // ── attachment 便捷取值 ──
  /// 附件类型：`recommendation_feed` / `microdesign_poster`。
  String get attachmentType => data['type'] as String? ?? '';

  /// 附件负载（推荐 feed 或海报 spec 的完整 JSON）。
  Map<String, dynamic> get payload =>
      (data['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
}
