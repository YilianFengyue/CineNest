import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/chat/widgets/agent_status_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/attachment_card.dart';
import 'package:cine_nest/pages/creative/chat/widgets/chat_composer.dart';
import 'package:cine_nest/pages/creative/chat/widgets/chat_history_drawer.dart';
import 'package:cine_nest/pages/creative/chat/widgets/recommend_sheet.dart';
import 'package:cine_nest/pages/creative/creative_actions.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/preview/card_gallery_page.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatController;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:get/get.dart';

/// AI 头像（本地 asset，避免 Pinterest 域名被墙拉不到）。
const String _kBotAvatarAsset = 'assets/pinterest1.png';
const String _kUserAvatarAsset = 'assets/pinterest2.png';

/// F9 AI 对话页 —— 仿 Gemini 的全屏对话。
///
/// 自带 AppBar（汉堡 → 侧边历史抽屉）+ 流式 Agent 回复 + 消息操作栏（复制/重生成）
/// + 推荐/海报/资讯结构化卡片。主题取系统 Material You（[ChatTheme.fromThemeData]）。
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  ChatController get _c => Get.isRegistered<ChatController>()
      ? Get.find<ChatController>()
      : Get.put(ChatController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: '历史对话',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('CineNest 助手'),
        actions: [
          IconButton(
            tooltip: '为你推荐',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => showRecommendSheet(context),
          ),
          IconButton(
            tooltip: '新对话',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: c.newSession,
          ),
        ],
      ),
      drawer: const ChatHistoryDrawer(),
      body: _ChatView(c: c),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({required this.c});

  final ChatController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chat(
      chatController: c.chat,
      currentUserId: ChatUsers.me,
      resolveUser: (id) async => User(id: id, name: id == ChatUsers.bot ? 'CineNest' : '我'),
      theme: ChatTheme.fromThemeData(theme),
      builders: Builders(
        textMessageBuilder: (ctx, message, index, {required isSentByMe, groupStatus}) {
          final bubble = FlyerChatTextMessage(message: message, index: index);
          // Agent 回复气泡下挂"复制 / 重新生成"操作栏（仿 Gemini）。
          if (isSentByMe || message.text.trim().isEmpty) return bubble;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble,
              _BotMessageActions(text: message.text, index: index),
            ],
          );
        },
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
        : const SizedBox(width: 32);
    return ChatMessage(
      message: message,
      index: index,
      animation: animation,
      isRemoved: isRemoved,
      groupStatus: groupStatus,
      // 头像顶对齐首行（默认底对齐，长消息会把头像垂到底部）。
      sentMessageRowAlignment: CrossAxisAlignment.start,
      receivedMessageRowAlignment: CrossAxisAlignment.start,
      leadingWidget: isSentByMe
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: avatar,
            ),
      trailingWidget: isSentByMe
          ? Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
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

/// Agent 回复下的操作栏 —— 复制 / 重新生成（仿 Gemini）。
class _BotMessageActions extends StatelessWidget {
  const _BotMessageActions({required this.text, required this.index});

  final String text;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = ChatController.to;
    // 仅最后一条 Agent 消息允许"重新生成"。
    final isLast = index == c.chat.messages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(
            icon: Icons.copy_rounded,
            tooltip: '复制',
            color: cs.onSurfaceVariant,
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (isLast)
            Obx(
              () => c.responding.value
                  ? const SizedBox.shrink()
                  : _IconAction(
                      icon: Icons.refresh_rounded,
                      tooltip: '重新生成',
                      color: cs.onSurfaceVariant,
                      onTap: c.retry,
                    ),
            ),
        ],
      ),
    );
  }
}

/// 小号涟漪图标按钮。
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

/// 对话头像 —— 本地 asset 圆头像（CircleAvatar 组件，自动对齐），
/// asset 缺失时回退到 colorScheme 底色 + 图标，不依赖网络。
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.isBot});

  final bool isBot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: isBot ? cs.primaryContainer : cs.surfaceContainerHighest,
      foregroundImage: AssetImage(isBot ? _kBotAvatarAsset : _kUserAvatarAsset),
      onForegroundImageError: (_, _) {},
      child: Icon(
        isBot ? Icons.auto_awesome : Icons.person,
        size: 16,
        color: isBot ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
    );
  }
}

/// 图片气泡 —— 本地选择的图（file 路径）与网络图都能渲染。
///
/// ⚠️ 关键：安卓相册/拍照返回的本地路径以 `/` 开头（如 `/data/.../xxx.jpg`），
/// 不能用 `startsWith('/')` 判网络，否则会被当成后端地址拼成 URL 去请求而显示灰块。
/// 这里只把 http(s) 与后端资产路径 `/api/` 当远程，其余一律按本地文件渲染。
class _ChatImageBubble extends StatelessWidget {
  const _ChatImageBubble({required this.message});

  final ImageMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = message.source;
    final isRemote = source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('/api/');

    Widget broken() => Container(
      width: 180,
      height: 120,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: cs.outline),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
        child: isRemote
            ? CachedNetworkImage(
                imageUrl: mediaUrl(source),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 180,
                  height: 180,
                  color: cs.surfaceContainerHighest,
                ),
                errorWidget: (_, _, _) => broken(),
              )
            : Image.file(
                File(source),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => broken(),
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
            Text('我是 CineNest 影视助手', style: theme.textTheme.titleMedium),
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
