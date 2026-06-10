import 'package:cine_nest/pages/creative/preview/card_mock.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:flutter/material.dart';

/// 交互卡片预览画廊（成员 C · 设计走查用）。
///
/// 用 mock 数据渲染全部 `microdesign.v1.1` 富卡，脱离后端即可校验视觉与交互。
/// 点击动作弹 SnackBar 提示（真链路在对话/海报页接 `onAction`）。
class CardGalleryPage extends StatelessWidget {
  const CardGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = cardGalleryMocks();
    return Scaffold(
      appBar: AppBar(title: const Text('交互卡片预览')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, i) {
          final item = items[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              BlockRenderer(
                blocks: [item.block],
                onAction: (a) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('动作：${a.type}')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
