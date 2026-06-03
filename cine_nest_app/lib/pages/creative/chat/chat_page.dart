import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_store.dart';
import 'package:cine_nest/pages/creative/chat/widgets/agent_status_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/attachment_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/chat_composer.dart';
import 'package:cine_nest/pages/creative/chat/widgets/recommend_sheet.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatController;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:get/get.dart';

/// F9 AI 对话页 —— 基于 flutter_chat_ui v2 的电影 Agent 对话。
///
/// 接后端 `/ws/chat` 流式 Agent：用户气泡 + 思考/来源状态条 + Markdown 回复
/// + 推荐/海报结构化卡片。主题取系统 Material You（[ChatTheme.fromThemeData]）。
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  ChatController get _c => Get.isRegistered<ChatController>()
      ? Get.find<ChatController>()
      : Get.put(ChatController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final theme = Theme.of(context);
    return Chat(
      chatController: c.chat,
      currentUserId: ChatUsers.me,
      resolveUser: (id) async => User(
        id: id,
        name: id == ChatUsers.bot ? 'CineNest' : '我',
      ),
      theme: ChatTheme.fromThemeData(theme),
      builders: Builders(
        textMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) =>
            FlyerChatTextMessage(message: message, index: index),
        customMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) =>
            _buildCustom(ctx, message),
        composerBuilder: (ctx) => const ChatComposer(),
        emptyChatListBuilder: (ctx) => _EmptyState(onPrompt: c.send),
      ),
    );
  }

  /// 按 metadata.kind 分发自定义消息：状态条 / 推荐卡 / 海报卡 / 错误条。
  Widget _buildCustom(BuildContext context, CustomMessage message) {
    final kind = message.metadata?[ChatMeta.kind] as String?;
    switch (kind) {
      case ChatMeta.kindStatus:
        return AgentStatusCard(message);
      case ChatMeta.kindRecommendation:
      case ChatMeta.kindPoster:
        return AttachmentCard(
          message,
          onAction: (a) => handleChatAction(context, a),
        );
      case ChatMeta.kindError:
        return _ErrorCard(
          text: message.metadata?[ChatMeta.text] as String? ?? '出错了',
          onRetry: ChatController.to.retry,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 统一处理对话卡片里的白名单动作。
///
/// 当前 F8 海报详情页与 A 的播放器尚未接入，先给出明确占位提示；
/// 后续：openPoster → 跳 F8 海报页（带 catalog id）；resolveAndPlay → 跳 A 的 /player。
void handleChatAction(BuildContext context, MicroAction action) {
  final messenger = ScaffoldMessenger.of(context);
  switch (action.type) {
    case 'openPoster':
    case 'openResourcePoster':
      // TODO(C): 接 F8 海报详情页，参数见 action.data。
      messenger.showSnackBar(
        const SnackBar(content: Text('互动海报详情页开发中（F8 下一步）')),
      );
      break;
    case 'resolveAndPlay':
      // TODO(C↔A): 跳 A 的播放器 /player，或先 GET /api/sources/parse 拿 play_url。
      messenger.showSnackBar(
        const SnackBar(content: Text('播放将对接 A 的播放器（联调期接入）')),
      );
      break;
    default:
      break;
  }
}

/// 对话页的 AppBar 操作（新对话 / 历史 / 推荐），由 main_app 注入到全局 AppBar。
List<Widget> chatAppBarActions(BuildContext context) {
  return [
    IconButton(
      tooltip: '为你推荐',
      icon: const Icon(Icons.auto_awesome_outlined),
      onPressed: () => showRecommendSheet(context),
    ),
    IconButton(
      tooltip: '历史对话',
      icon: const Icon(Icons.history),
      onPressed: () => _showHistory(context),
    ),
    IconButton(
      tooltip: '新对话',
      icon: const Icon(Icons.add_comment_outlined),
      onPressed: () => ChatController.to.newSession(),
    ),
  ];
}

Future<void> _showHistory(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final sessions = ChatStore.sessions();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('历史对话', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Text(
                    '还没有历史对话',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${s.messageCount} 条消息'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ChatController.to.deleteSession(s.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                        onTap: () {
                          ChatController.to.loadSession(s.id);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// 错误条 + 重试。
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// 空态：欢迎语 + 快捷提问。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPrompt});

  final void Function(String) onPrompt;

  static const _prompts = <String>[
    '推荐几部最近的高分电影',
    '有什么像《盗梦空间》的烧脑片',
    '找部能直接播放的科幻片',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.movie_creation_outlined,
                  color: cs.onPrimaryContainer, size: 32),
            ),
            const SizedBox(height: 16),
            Text('我是 CineNest 影视助手',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '告诉我你想看什么，我帮你找片、聊剧情、生成互动海报。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final p in _prompts)
                  ActionChip(label: Text(p), onPressed: () => onPrompt(p)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
