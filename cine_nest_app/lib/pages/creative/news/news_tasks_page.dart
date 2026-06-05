import 'package:cine_nest/pages/creative/news/news_tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 资讯生成任务页（F12）—— 全部任务历史（只读）。
///
/// 实时显示每条任务的状态（排队 / 生成中 / 已完成 / 失败）与进度条。
/// 生成入口在「对话页 ➕ → 生成影视资讯」，这里只看进度，完成可点"查看"。
/// 设计：Material You tonal、零阴影、紧凑。
class NewsTasksPage extends StatelessWidget {
  const NewsTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NewsTasksController.to;
    return Scaffold(
      appBar: AppBar(
        title: const Text('生成任务'),
        actions: [
          Obx(
            () => c.usingMock.value
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(child: _MockChip()),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        final list = c.tasks;
        if (list.isEmpty) return const _EmptyTasks();
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => NewsTaskCard(task: list[i]),
          ),
        );
      }),
    );
  }
}

/// 单条任务卡（带进度条）。资讯页队列区与本页共用。
class NewsTaskCard extends StatelessWidget {
  const NewsTaskCard({super.key, required this.task, this.onView});

  final NewsTask task;

  /// "查看"回调（完成任务）；不传则默认 pop 回上一页。
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = task.isFailed
        ? cs.error
        : (task.isDone ? cs.primary : cs.onSurfaceVariant);

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: task.isDone ? (onView ?? Get.back) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusDot(task: task),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    task.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (task.isDone) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: cs.outline),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.isActive ? null : task.progress,
                  minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: task.isFailed ? cs.error : cs.primary,
                ),
              ),
              if (task.isFailed && (task.error ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.error!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态圆点 / 转圈。
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.task});
  final NewsTask task;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (task.isActive) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary),
      );
    }
    return Icon(
      task.isDone ? Icons.check_circle : Icons.error_outline,
      size: 20,
      color: task.isDone ? cs.primary : cs.error,
    );
  }
}

class _MockChip extends StatelessWidget {
  const _MockChip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '示例数据',
        style: TextStyle(
          fontSize: 11,
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.playlist_add_check, size: 44, color: cs.outline),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '还没有生成任务\n上方输入片名开始生成',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
        ),
      ],
    );
  }
}
