import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:flutter/material.dart';

/// 「为你推荐」底部 sheet（成员 C · F9）。
///
/// 预留位：后续接「识别产生海报 / 资讯推荐 / 定期推荐」的推送 list，
/// 当前先做空态 + 快捷提问 chip（点了直接发给 Agent，复用对话链路）。
Future<void> showRecommendSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    isScrollControlled: true,
    builder: (ctx) => const _RecommendSheet(),
  );
}

class _RecommendSheet extends StatelessWidget {
  const _RecommendSheet();

  // 快捷提问预设，点了发给 Agent。
  static const _prompts = <String>[
    '推荐几部最近热门的电影',
    '有什么像《星际穿越》的科幻片',
    '找几部适合周末放松的喜剧',
    '推荐高分悬疑片，最好能直接播放',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('为你推荐', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '定期推荐与资讯推送即将上线，先试试让 Agent 帮你找片：',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // 预留：定期推荐 list（空态）。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.notifications_none, color: cs.outline, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    '暂无定期推荐',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 直连后端 /api/feed/recommend（不走 LLM），即刻拉真实推荐卡。
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(context);
                      ChatController.to.injectRecommendationFeed();
                    },
                    icon: const Icon(Icons.bolt_outlined, size: 18),
                    label: const Text('看看热门推荐'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '快捷提问',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _prompts)
                  ActionChip(
                    label: Text(p),
                    onPressed: () {
                      Navigator.pop(context);
                      ChatController.to.send(p);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
