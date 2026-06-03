import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_store.dart';
import 'package:cine_nest/pages/creative/chat/widgets/agent_status_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/attachment_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/chat_composer.dart';
import 'package:cine_nest/pages/creative/chat/widgets/recommend_sheet.dart';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/creative_actions.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/preview/card_gallery_page.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatController;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:get/get.dart';

/// AI 头像（Pinterest 占位，后续可换品牌头像）。
const String _kBotAvatar =
    'https://i.pinimg.com/1200x/1e/13/03/1e13037dc1891540fd0f1761f99a0d69.jpg';

/// 用户头像占位。
const String _kUserAvatar =
    'https://i.pinimg.com/736x/43/27/dd/4327ddd546e01c0a5cd6de3c2f173f78.jpg';

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
        imageSource: id == ChatUsers.bot ? _kBotAvatar : _kUserAvatar,
      ),
      theme: ChatTheme.fromThemeData(theme),
      builders: Builders(
        textMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) =>
            FlyerChatTextMessage(message: message, index: index),
        imageMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) =>
            _ChatImageBubble(message: message),
        customMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) =>
            _buildCustom(ctx, message),
        chatMessageBuilder: _wrapWithAvatar,
        composerBuilder: (ctx) => const ChatComposer(),
        emptyChatListBuilder: (ctx) => _EmptyState(onPrompt: c.send),
      ),
    );
  }

  /// 给文本/图片气泡两侧挂头像（同组只在末条显示，保持对齐）；
  /// 卡片 / 状态条 / 错误条通栏，不套气泡框架。
  Widget _wrapWithAvatar(
    BuildContext context,
    Message message,
    int index,
    Animation<double> animation,
    Widget child, {
    bool? isRemoved,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final isBubble = message is TextMessage || message is ImageMessage;
    if (!isBubble) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: child,
      );
    }
    final showAvatar = groupStatus == null || groupStatus.isLast;
    final avatar = showAvatar
        ? _ChatAvatar(isBot: message.authorId == ChatUsers.bot)
        : const SizedBox(width: 30);
    return ChatMessage(
      message: message,
      index: index,
      animation: animation,
      isRemoved: isRemoved,
      groupStatus: groupStatus,
      leadingWidget: isSentByMe
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: avatar,
            ),
      trailingWidget: isSentByMe
          ? Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: avatar,
            )
          : null,
      child: child,
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
      case ChatMeta.kindInteractive:
      case ChatMeta.kindNews:
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

/// 对话卡片动作 → 统一分发（openPoster 跳海报、resolveAndPlay 解析播放）。
void handleChatAction(BuildContext context, MicroAction action) {
  handleCreativeAction(context, action);
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

/// 对话头像 —— 优先加载网络头像，拉不到（如 pinimg 被墙）则画渐变圆 + 图标兜底。
///
/// 不用 flyer 的 Avatar：它失败时只回退文字首字母，观感差；这里给一个体面的兜底。
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.isBot});

  final bool isBot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = isBot ? _kBotAvatar : _kUserAvatar;
    final fallback = _fallback(cs);
    return ClipOval(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme cs) {
    if (isBot) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.tertiary],
          ),
        ),
        child: Icon(Icons.auto_awesome, size: 16, color: cs.onPrimary),
      );
    }
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.person, size: 18, color: cs.onSurfaceVariant),
    );
  }
}

/// 图片气泡 —— 本地选择的图（file 路径）与网络图都能渲染。
///
/// 自写而非依赖 flyer_chat_image_message：本地相册/拍照得到的是文件路径，
/// 用 [Image.file] 直渲染最稳；网络图走 [CachedNetworkImage] 兜底。
class _ChatImageBubble extends StatelessWidget {
  const _ChatImageBubble({required this.message});

  final ImageMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = message.source;
    // 远程图(含相对 /api/assets) 走网络；本地 file 路径走 Image.file。
    final isNetwork = source.startsWith('http') || source.startsWith('/');
    final resolved = mediaUrl(source);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(width: 180, height: 180, color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => Container(
                  width: 180,
                  height: 120,
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: cs.outline),
                ),
              )
            : Image.file(
                File(source),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 180,
                  height: 120,
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: cs.outline),
                ),
              ),
      ),
    );
  }
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
            const SizedBox(height: 24),
            // 一键预览全部交互卡片（mock，不依赖后端）。
            FilledButton.tonalIcon(
              onPressed: () => Get.to(() => const CardGalleryPage()),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('预览交互卡片（7 张 · mock）'),
            ),
          ],
        ),
      ),
    );
  }
}
