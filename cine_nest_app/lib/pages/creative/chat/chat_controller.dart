import 'dart:async';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/chat/models/agent_event.dart';
import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_store.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_ws_service.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

/// F9 AI 对话控制器 —— 把后端 Agent 流式事件编排成 Chat UI 的消息操作。
///
/// 事件映射（见 [_onEvent]）：
///   started      → 状态条进入「思考中」
///   tool_started → 状态条追加来源 chip
///   attachment   → 插入推荐 / 海报卡片
///   delta        → 累加助手文本气泡（Markdown）
///   done         → 状态条停转、收尾、落盘
///   error        → 错误条 + 重试
class ChatController extends GetxController {
  static ChatController get to => Get.find<ChatController>();

  final InMemoryChatController chat = InMemoryChatController();
  final ChatWsService ws = ChatWsService();

  /// 当前会话 id（= thread_id），服务端按它保留多轮上下文。
  late String threadId;

  /// 是否正在等待 Agent 回复（用于禁用发送、显示状态）。
  final RxBool responding = false.obs;

  /// 当前选中模型 id。
  final RxString modelId = ChatModelPref.id.obs;

  StreamSubscription<AgentEvent>? _eventSub;
  int _seq = 0;

  // 当前回合的临时状态。
  String? _statusMsgId; // Agent 状态条消息 id
  String? _assistantMsgId; // 助手文本气泡 id
  String _assistantBuffer = ''; // 累加的助手文本
  String _lastUserText = ''; // 最近一条用户消息（重试用）

  @override
  void onInit() {
    super.onInit();
    threadId = _newId('t');
    _eventSub = ws.events.listen(_onEvent);
  }

  @override
  void onClose() {
    _persist();
    _eventSub?.cancel();
    ws.dispose();
    chat.dispose();
    super.onClose();
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // ───────────────────────── 发送 ─────────────────────────

  /// 发送一条用户消息并触发 Agent 流程。
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || responding.value) return;
    _lastUserText = trimmed;

    await chat.insertMessage(
      Message.text(
        id: _newId('u'),
        authorId: ChatUsers.me,
        createdAt: DateTime.now().toUtc(),
        text: trimmed,
        sentAt: DateTime.now().toUtc(),
      ),
    );

    // 起一个新回合：清空临时状态，先插入「思考中」状态条（乐观显示）。
    responding.value = true;
    _assistantMsgId = null;
    _assistantBuffer = '';
    _statusMsgId = _newId('s');
    await chat.insertMessage(
      Message.custom(
        id: _statusMsgId!,
        authorId: ChatUsers.bot,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          ChatMeta.kind: ChatMeta.kindStatus,
          ChatMeta.thinking: true,
          ChatMeta.tools: <String>[],
        },
      ),
    );

    final ok = await ws.send(
      message: trimmed,
      threadId: threadId,
      model: modelId.value,
    );
    if (!ok) {
      // 连接失败：错误事件已由 ws 推送，这里兜底收尾。
      await _finishTurn();
    }
    _persist();
  }

  /// 重试最近一条用户消息。
  Future<void> retry() async {
    if (_lastUserText.isEmpty || responding.value) return;
    final text = _lastUserText;
    // 复用 send，但不重复插入用户气泡 —— 直接走一次新回合。
    responding.value = true;
    _assistantMsgId = null;
    _assistantBuffer = '';
    _statusMsgId = _newId('s');
    await chat.insertMessage(
      Message.custom(
        id: _statusMsgId!,
        authorId: ChatUsers.bot,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          ChatMeta.kind: ChatMeta.kindStatus,
          ChatMeta.thinking: true,
          ChatMeta.tools: <String>[],
        },
      ),
    );
    final ok = await ws.send(
      message: text,
      threadId: threadId,
      model: modelId.value,
    );
    if (!ok) await _finishTurn();
  }

  /// 发送一张图片消息（本地渲染）。
  ///
  /// 当前后端 Agent 仅支持文本，这里先把图片作为用户消息展示在对话里；
  /// 随消息一并喂给模型需后端多模态支持（见 docs 返工清单）。
  Future<void> sendImage(String path) async {
    await chat.insertMessage(
      Message.image(
        id: _newId('img'),
        authorId: ChatUsers.me,
        createdAt: DateTime.now().toUtc(),
        source: path,
        sentAt: DateTime.now().toUtc(),
      ),
    );
    _persist();
  }

  /// 直连 `/api/feed/recommend`（确定性 REST，不走 LLM）拉推荐并注入卡片。
  ///
  /// 用于在模型未配置 / 未触发推荐工具时，仍能演示与验证推荐卡片设计。
  Future<void> injectRecommendationFeed({String query = ''}) async {
    if (responding.value) return;
    responding.value = true;
    final statusId = _newId('s');
    await chat.insertMessage(
      Message.custom(
        id: statusId,
        authorId: ChatUsers.bot,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          ChatMeta.kind: ChatMeta.kindStatus,
          ChatMeta.thinking: true,
          ChatMeta.tools: const ['build_recommendation_feed'],
        },
      ),
    );
    try {
      final res = await Request().get(
        ApiConstants.feedRecommend,
        queryParameters: {'query': query, 'limit': 6},
      );
      final data = res.data;
      final payload = data is Map
          ? data.cast<String, dynamic>()
          : <String, dynamic>{};
      await _stopStatus(statusId);
      final posts = payload['posts'];
      if (posts is List && posts.isNotEmpty) {
        await chat.insertMessage(
          Message.custom(
            id: _newId('a'),
            authorId: ChatUsers.bot,
            createdAt: DateTime.now().toUtc(),
            metadata: {
              ChatMeta.kind: ChatMeta.kindRecommendation,
              ChatMeta.payload: payload,
            },
          ),
        );
      } else {
        await _insertError('暂未找到可推荐的可播放资源，换个关键词试试。');
      }
    } catch (e) {
      logger.w('直连推荐失败: $e');
      await _stopStatus(statusId);
      await _insertError('推荐拉取失败，请检查后端连接。');
    }
    responding.value = false;
    _persist();
  }

  /// 停掉指定状态条的思考态（保留来源 chip）。
  Future<void> _stopStatus(String statusId) async {
    final idx = chat.messages.indexWhere((m) => m.id == statusId);
    if (idx == -1) return;
    final old = chat.messages[idx];
    if (old is! CustomMessage) return;
    final meta = Map<String, dynamic>.from(old.metadata ?? {});
    meta[ChatMeta.thinking] = false;
    await chat.updateMessage(old, old.copyWith(metadata: meta));
  }

  // ───────────────────────── 事件编排 ─────────────────────────

  Future<void> _onEvent(AgentEvent e) async {
    switch (e.type) {
      case AgentEventType.started:
        // 状态条已在 send 时插入；这里确保 thinking=true。
        await _setStatusThinking(true);
        break;
      case AgentEventType.toolStarted:
        await _appendTool(e.toolName);
        break;
      case AgentEventType.toolFinished:
        // 调试信息，UI 忽略内容。
        break;
      case AgentEventType.attachment:
        await _insertAttachment(e);
        break;
      case AgentEventType.delta:
        await _appendDelta(e.content);
        break;
      case AgentEventType.done:
        await _finishTurn();
        _persist();
        break;
      case AgentEventType.error:
        await _insertError(e.content.isEmpty ? '出错了，请稍后重试。' : e.content);
        await _finishTurn();
        _persist();
        break;
      case AgentEventType.unknown:
        break;
    }
  }

  /// 找到当前状态条消息（可能已被更新过）。
  CustomMessage? get _statusMsg {
    if (_statusMsgId == null) return null;
    final idx = chat.messages.indexWhere((m) => m.id == _statusMsgId);
    if (idx == -1) return null;
    final m = chat.messages[idx];
    return m is CustomMessage ? m : null;
  }

  Future<void> _setStatusThinking(bool thinking) async {
    final old = _statusMsg;
    if (old == null) return;
    final meta = Map<String, dynamic>.from(old.metadata ?? {});
    meta[ChatMeta.thinking] = thinking;
    await chat.updateMessage(old, old.copyWith(metadata: meta));
  }

  Future<void> _appendTool(String toolName) async {
    if (toolName.isEmpty) return;
    final old = _statusMsg;
    if (old == null) return;
    final meta = Map<String, dynamic>.from(old.metadata ?? {});
    final tools = List<String>.from(
      (meta[ChatMeta.tools] as List?)?.map((e) => e.toString()) ?? const [],
    );
    tools.add(toolName);
    meta[ChatMeta.tools] = tools;
    meta[ChatMeta.thinking] = true;
    await chat.updateMessage(old, old.copyWith(metadata: meta));
  }

  Future<void> _insertAttachment(AgentEvent e) async {
    final kind = e.attachmentType == ChatMeta.kindPoster
        ? ChatMeta.kindPoster
        : ChatMeta.kindRecommendation;
    await chat.insertMessage(
      Message.custom(
        id: _newId('a'),
        authorId: ChatUsers.bot,
        createdAt: DateTime.now().toUtc(),
        metadata: {ChatMeta.kind: kind, ChatMeta.payload: e.payload},
      ),
    );
  }

  Future<void> _appendDelta(String content) async {
    if (content.isEmpty) return;
    _assistantBuffer = _assistantBuffer.isEmpty
        ? content
        : '$_assistantBuffer\n\n$content';

    if (_assistantMsgId == null) {
      _assistantMsgId = _newId('m');
      await chat.insertMessage(
        Message.text(
          id: _assistantMsgId!,
          authorId: ChatUsers.bot,
          createdAt: DateTime.now().toUtc(),
          text: _assistantBuffer,
        ),
      );
    } else {
      final idx = chat.messages.indexWhere((m) => m.id == _assistantMsgId);
      if (idx != -1) {
        final old = chat.messages[idx];
        if (old is TextMessage) {
          await chat.updateMessage(old, old.copyWith(text: _assistantBuffer));
        }
      }
    }
  }

  Future<void> _insertError(String text) async {
    await chat.insertMessage(
      Message.custom(
        id: _newId('e'),
        authorId: ChatUsers.bot,
        createdAt: DateTime.now().toUtc(),
        metadata: {ChatMeta.kind: ChatMeta.kindError, ChatMeta.text: text},
      ),
    );
  }

  /// 收尾一个回合：停转状态条、标记助手消息已送达、解锁发送。
  Future<void> _finishTurn() async {
    await _setStatusThinking(false);
    // 若状态条没有任何工具记录（纯闲聊），移除它以保持简洁。
    final status = _statusMsg;
    if (status != null) {
      final tools =
          (status.metadata?[ChatMeta.tools] as List?)?.isEmpty ?? true;
      if (tools) await chat.removeMessage(status);
    }
    if (_assistantMsgId != null) {
      final idx = chat.messages.indexWhere((m) => m.id == _assistantMsgId);
      if (idx != -1) {
        final old = chat.messages[idx];
        if (old is TextMessage && old.sentAt == null) {
          await chat.updateMessage(
            old,
            old.copyWith(sentAt: DateTime.now().toUtc()),
          );
        }
      }
    }
    _statusMsgId = null;
    responding.value = false;
  }

  // ───────────────────────── 会话管理 ─────────────────────────

  /// 切换模型（前端展示；后端待接 model 字段）。
  Future<void> setModel(String id) async {
    modelId.value = id;
    await ChatModelPref.set(id);
  }

  /// 新建会话：落盘当前会话，清空消息，换新 thread_id。
  Future<void> newSession() async {
    _persist();
    await ws.disconnect();
    await chat.setMessages([]);
    threadId = _newId('t');
    _statusMsgId = null;
    _assistantMsgId = null;
    _assistantBuffer = '';
    responding.value = false;
  }

  /// 加载历史会话。
  Future<void> loadSession(String sessionId) async {
    if (sessionId == threadId) return;
    _persist();
    await ws.disconnect();
    final msgs = ChatStore.messages(sessionId);
    await chat.setMessages(msgs);
    threadId = sessionId;
    responding.value = false;
  }

  /// 删除历史会话；若删的是当前会话则新建空会话。
  Future<void> deleteSession(String sessionId) async {
    await ChatStore.delete(sessionId);
    if (sessionId == threadId) await newSession();
  }

  void _persist() {
    final msgs = chat.messages;
    if (msgs.isEmpty) return;
    ChatStore.save(
      sessionId: threadId,
      title: _titleFrom(msgs),
      messages: msgs,
    ).catchError((e) => logger.w('对话落盘失败: $e'));
  }

  /// 取首条用户文本作为会话标题。
  String _titleFrom(List<Message> msgs) {
    for (final m in msgs) {
      if (m is TextMessage && m.authorId == ChatUsers.me) {
        final t = m.text.trim().replaceAll('\n', ' ');
        return t.length <= 18 ? t : '${t.substring(0, 18)}…';
      }
    }
    return '新对话';
  }
}
