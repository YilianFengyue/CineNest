import 'package:cine_nest/pages/creative/chat/widgets/tool_source.dart';
import 'package:flutter/material.dart';

/// 来源 chip —— Agent 调用工具时显示「查了哪个源」。
///
/// Material You tonal 风格：已实现来源用 secondaryContainer，
/// 规划中来源置灰（surfaceContainerHighest）并标注「即将」。
class ToolChip extends StatelessWidget {
  const ToolChip(this.source, {super.key});

  final ToolSource source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = source.implemented
        ? cs.secondaryContainer
        : cs.surfaceContainerHighest;
    final fg = source.implemented
        ? cs.onSecondaryContainer
        : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            source.implemented ? source.label : '${source.label} · 即将',
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
