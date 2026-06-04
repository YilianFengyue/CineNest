import 'package:cine_nest/pages/creative/news/news_tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 资讯生成任务队列页（F12）。
///
/// 顶部输入主题 → 提交一条异步生成任务；下方实时显示队列里每条任务的状态
/// （排队 / 生成中 / 已完成 / 失败）。完成的任务可点"查看"回资讯列表。
/// 设计：Material You tonal、零阴影、紧凑。
class NewsTasksPage extends StatelessWidget {
  const NewsTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(NewsTasksController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('资讯生成队列'),
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
      body: Column(
        children: [
          _GenerateBar(c: c),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final list = c.tasks;
              if (list.isEmpty) return const _EmptyTasks();
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TaskCard(task: list[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 顶部生成输入条。
class _GenerateBar extends StatefulWidget {
  const _GenerateBar({required this.c});
  final NewsTasksController c;

  @override
  State<_GenerateBar> createState() => _GenerateBarState();
}

class _GenerateBarState extends State<_GenerateBar> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    await widget.c.submit(q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '输入片名 / 主题生成资讯，如：星际穿越',
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                prefixIcon: const Icon(Icons.auto_awesome, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: const OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => FilledButton(
              onPressed: widget.c.submitting.value ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: widget.c.submitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('生成'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条任务卡。
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final NewsTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final v = _visual(cs);

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: task.isDone ? () => Get.back() : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 状态图标 / 进度圈
              SizedBox(
                width: 28,
                height: 28,
                child: task.isActive
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: cs.primary,
                        ),
                      )
                    : Icon(v.icon, color: v.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.isFailed
                          ? (task.error ?? '生成失败')
                          : (task.stage.isEmpty ? v.label : task.stage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: v.color),
                    ),
                  ],
                ),
              ),
              if (task.isDone)
                TextButton(onPressed: () => Get.back(), child: const Text('查看')),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _visual(ColorScheme cs) {
    switch (task.status) {
      case 'done':
        return (icon: Icons.check_circle, color: cs.primary, label: '已完成');
      case 'failed':
        return (icon: Icons.error_outline, color: cs.error, label: '失败');
      case 'running':
        return (icon: Icons.sync, color: cs.primary, label: '生成中');
      default:
        return (
          icon: Icons.schedule,
          color: cs.onSurfaceVariant,
          label: '排队中',
        );
    }
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
