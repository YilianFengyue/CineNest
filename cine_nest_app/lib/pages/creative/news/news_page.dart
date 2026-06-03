import 'package:cine_nest/pages/creative/creative_actions.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/news/news_controller.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 资讯 Tab 页（F12）—— 后端 `/api/news` 图文卡片流 + 下拉刷新 + AI 生成资讯。
///
/// 每条资讯的 `blocks`（newsCard + 可选 mediaGallery）直接走 [BlockRenderer]，
/// newsCard 自带点击动作（openPoster）跳互动海报。
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(NewsController());
    return Stack(
      children: [
        Obx(() {
          if (c.loading.value && c.items.isEmpty) {
            return const _NewsSkeletonList();
          }
          if (c.items.isEmpty) {
            return _EmptyView(
              message: c.error.value.isEmpty ? '暂无资讯' : c.error.value,
              onRetry: () => c.refreshNews(refresh: true),
            );
          }
          return RefreshIndicator(
            onRefresh: () => c.refreshNews(refresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: c.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final entry = c.items[i];
                return BlockRenderer(
                  blocks: entry.blocks,
                  spacing: 10,
                  onAction: (a) => _handleAction(context, a),
                );
              },
            ),
          );
        }),
        // AI 生成资讯入口
        Positioned(
          right: 16,
          bottom: 16,
          child: Obx(
            () => FloatingActionButton.extended(
              onPressed: c.generating.value
                  ? null
                  : () => _showGenerateDialog(context, c),
              icon: c.generating.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(c.generating.value ? '生成中…' : 'AI 资讯'),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, MicroAction action) {
    handleCreativeAction(context, action);
  }

  Future<void> _showGenerateDialog(
    BuildContext context,
    NewsController c,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 生成资讯'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入片名或主题，如：星际穿越',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('AI 正在生成资讯与海报图，约需十几秒…')),
    );
    final ok = await c.generateNews(query);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? '已生成《$query》资讯' : '生成失败，换个片名试试')),
    );
  }
}

// ── 空 / 错误态 ──────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Icon(Icons.article_outlined, size: 44, color: cs.outline),
        const SizedBox(height: 12),
        Center(
          child: Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 14),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }
}

// ── 骨架屏 ──────────────────────────────────────────────

class _NewsSkeletonList extends StatelessWidget {
  const _NewsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PulseBox(height: 18, widthFactor: 0.85),
            SizedBox(height: 8),
            _PulseBox(height: 18, widthFactor: 0.5),
            SizedBox(height: 16),
            _PulseBox(height: 150, widthFactor: 1, radius: 10),
            SizedBox(height: 12),
            _PulseBox(height: 12, widthFactor: 1),
            SizedBox(height: 8),
            _PulseBox(height: 12, widthFactor: 0.7),
          ],
        ),
      ),
    );
  }
}

/// 呼吸式占位块。
class _PulseBox extends StatefulWidget {
  const _PulseBox({this.widthFactor, required this.height, this.radius = 6});

  final double? widthFactor;
  final double height;
  final double radius;

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.widthFactor,
        child: AnimatedBuilder(
          animation: _ac,
          builder: (_, _) => Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(
                cs.surfaceContainerHighest,
                cs.surfaceContainerHigh,
                _ac.value,
              ),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        ),
      ),
    );
  }
}
