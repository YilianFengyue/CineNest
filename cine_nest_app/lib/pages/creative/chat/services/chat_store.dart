import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:hive_ce/hive.dart';

/// 单个对话会话的元信息（用于历史列表展示）。
class ChatSessionMeta {
  final String id; // = thread_id
  final String title; // 取首条用户消息，截断
  final int createdAt; // epoch ms
  final int updatedAt; // epoch ms
  final int messageCount;

  const ChatSessionMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });
}

/// 对话本地持久化（成员 C · F9）。
///
/// 所有会话存进 [GStorage.localCache] 的单一键 [_key]，结构：
/// ```
/// { <sessionId>: { id, title, createdAt, updatedAt, messages: [ <Message.toJson> ... ] } }
/// ```
/// 消息直接复用 flutter_chat_core 的 `Message.toJson()` / `Message.fromJson()` 序列化，
/// 因此 TextMessage / CustomMessage(metadata) 都能完整往返。
///
/// 注：这是「前端展示历史」的持久化；服务端 Agent 上下文记忆（按 thread_id）是另一回事，
/// 重启即丢，跨会话记忆需后端换 SqliteSaver（见 docs 返工清单）。
abstract final class ChatStore {
  static const String _key = 'chatSessions';

  static Box get _box => GStorage.localCache;

  static Map<String, dynamic> _all() {
    final raw = _box.get(_key);
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static Future<void> _putAll(Map<String, dynamic> all) =>
      _box.put(_key, all);

  /// 会话列表，按更新时间倒序。
  static List<ChatSessionMeta> sessions() {
    final all = _all();
    final list = <ChatSessionMeta>[];
    for (final entry in all.values) {
      if (entry is! Map) continue;
      final m = entry.cast<String, dynamic>();
      final msgs = m['messages'];
      list.add(
        ChatSessionMeta(
          id: m['id'] as String? ?? '',
          title: m['title'] as String? ?? '新对话',
          createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
          updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
          messageCount: msgs is List ? msgs.length : 0,
        ),
      );
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 读取某会话的消息列表（损坏帧静默跳过）。
  static List<Message> messages(String sessionId) {
    final entry = _all()[sessionId];
    if (entry is! Map) return const [];
    final raw = entry['messages'];
    if (raw is! List) return const [];
    final out = <Message>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(Message.fromJson(item.cast<String, dynamic>()));
      } catch (e) {
        logger.w('对话历史消息解析失败，跳过: $e');
      }
    }
    return out;
  }

  /// 写入 / 覆盖一个会话。空消息会话不落盘。
  static Future<void> save({
    required String sessionId,
    required String title,
    required List<Message> messages,
    int? createdAt,
  }) async {
    if (messages.isEmpty) return;
    final all = _all();
    final existing = all[sessionId];
    final created = createdAt ??
        (existing is Map ? (existing['createdAt'] as num?)?.toInt() : null) ??
        DateTime.now().millisecondsSinceEpoch;
    all[sessionId] = {
      'id': sessionId,
      'title': title,
      'createdAt': created,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    await _putAll(all);
  }

  static Future<void> delete(String sessionId) async {
    final all = _all();
    all.remove(sessionId);
    await _putAll(all);
  }

  static Future<void> clearAll() => _box.delete(_key);
}
