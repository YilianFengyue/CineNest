import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/chat/widgets/tool_chip.dart';
import 'package:cine_nest/pages/creative/chat/widgets/tool_source.dart';
import 'package:cine_nest/pages/creative/chat/widgets/typing_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// Agent 状态条 —— 思考动画 + 已调用来源 chip。
///
/// 渲染 `kind=agent_status` 的 [CustomMessage]：
///   · `thinking=true` 时显示三点动画 +「正在检索…」
///   · `tools` 列表渲染成来源 chip（去重，保持出现顺序）
///   · 完成后（thinking=false）若有 tools，转为「已检索 N 个来源」回执
class AgentStatusCard extends StatelessWidget {
  const AgentStatusCard(this.message, {super.key});

  final CustomMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = message.metadata ?? const {};
    final thinking = meta[ChatMeta.thinking] == true;
    final toolNames = <String>[
      for (final t in (meta[ChatMeta.tools] as List? ?? const []))
        t.toString(),
    ];
    // 去重保序。
    final seen = <String>{};
    final sources = <ToolSource>[
      for (final name in toolNames)
        if (seen.add(name)) ToolSource.of(name),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (thinking) ...[
                  TypingDots(color: cs.primary),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(Icons.check_circle, size: 15, color: cs.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  thinking
                      ? (sources.isEmpty ? '正在思考…' : '正在检索资料…')
                      : (sources.isEmpty
                            ? '已完成'
                            : '已检索 ${sources.length} 个来源'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final s in sources) ToolChip(s)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
