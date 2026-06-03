import 'dart:async';
import 'dart:convert';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/pages/creative/chat/models/agent_event.dart';
import 'package:cine_nest/services/connection_service.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// WebSocket 连接状态。
enum WsState { idle, connecting, connected, closed, error }

/// Agent 对话 WebSocket 客户端。
///
/// 连接后端 `/ws/chat`，发送 `{message, thread_id, model}` 文本帧，
/// 把服务端的 JSON 帧解析成 [AgentEvent] 通过 [events] 广播。
///
/// 后端会按 `thread_id` 在服务端保留多轮上下文（`InMemorySaver`），
/// 因此即便中途断线重连，只要带同一 `thread_id` 仍可续上对话记忆。
/// （服务端记忆重启即丢，跨会话持久化属后端待办，见 docs 返工清单。）
class ChatWsService {
  ChatWsService();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final StreamController<AgentEvent> _events =
      StreamController<AgentEvent>.broadcast();

  WsState _state = WsState.idle;
  WsState get state => _state;

  /// 解析后的事件广播流，[ChatController] 订阅它。
  Stream<AgentEvent> get events => _events.stream;

  /// 把后端 HTTP 基址转成 ws(s) 基址。
  Uri get _wsUri {
    final base = ConnectionService.to.baseUrl; // http://host:port
    final wsBase = base.replaceFirst(RegExp(r'^http'), 'ws');
    return Uri.parse('$wsBase${ApiConstants.wsChat}');
  }

  bool get isConnected => _state == WsState.connected;

  /// 确保已连接；若已连或正在连则复用。返回是否连接成功。
  Future<bool> ensureConnected() async {
    if (_state == WsState.connected) return true;
    if (_state == WsState.connecting) return false;
    return _connect();
  }

  Future<bool> _connect() async {
    _state = WsState.connecting;
    try {
      final channel = WebSocketChannel.connect(_wsUri);
      await channel.ready; // 抛异常即连接失败
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _state = WsState.connected;
      logger.i('对话 WS 已连接: $_wsUri');
      return true;
    } catch (e) {
      _state = WsState.error;
      logger.w('对话 WS 连接失败: $e');
      _events.add(
        AgentEvent(
          type: AgentEventType.error,
          content: 'PC 端 Agent 服务未连接，请检查设置中的后端地址。',
        ),
      );
      return false;
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final event = AgentEvent.tryParse(raw);
    if (event == null) {
      logger.w('对话 WS 收到无法解析的帧: $raw');
      return;
    }
    _events.add(event);
  }

  void _onError(Object error, StackTrace st) {
    _state = WsState.error;
    logger.e('对话 WS 出错', error: error, stackTrace: st);
    _events.add(
      AgentEvent(type: AgentEventType.error, content: '连接中断：$error'),
    );
  }

  void _onDone() {
    _state = WsState.closed;
    logger.i('对话 WS 已关闭');
  }

  /// 发送一条用户消息。连接断开会自动尝试重连。
  ///
  /// [model] 为前端模型选择（后端当前忽略，待 Codex 适配后生效）。
  Future<bool> send({
    required String message,
    required String threadId,
    String? model,
  }) async {
    final ok = await ensureConnected();
    if (!ok || _channel == null) return false;
    final frame = jsonEncode({
      'message': message,
      'thread_id': threadId,
      if (model != null && model.isNotEmpty) 'model': model,
    });
    _channel!.sink.add(frame);
    return true;
  }

  /// 主动断开（切换会话或退出页面时）。
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    if (_state != WsState.error) _state = WsState.closed;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}

/// 默认模型选项（后端 `.env` 固定单模型，这里先写死展示，选择项待 Codex 接 `model` 字段）。
class ChatModelOption {
  final String id;
  final String label;
  final String hint;
  const ChatModelOption(this.id, this.label, this.hint);
}

/// 预置模型列表 —— 纯展示占位，便于演示「模型选择」交互。
const List<ChatModelOption> kChatModels = [
  ChatModelOption('default', 'CineNest 默认', '后端 .env 配置的模型，均衡稳定'),
  ChatModelOption('fast', '快速', '更快响应，适合简单问答（待后端支持）'),
  ChatModelOption('deep', '深度', '更强推理，适合复杂推荐（待后端支持）'),
];

/// 当前选中的模型（持久化于 setting box）。
class ChatModelPref {
  static String get id => Pref.chatModelId;
  static Future<void> set(String value) => Pref.setChatModelId(value);

  static ChatModelOption get current =>
      kChatModels.firstWhere((m) => m.id == id, orElse: () => kChatModels.first);
}
