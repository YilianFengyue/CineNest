import 'package:cine_nest/pages/creative/creative_actions.dart';
import 'package:cine_nest/pages/creative/favorites_controller.dart';
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
    final fav = FavoritesController.to;
    return Obx(() {
      if (c.loading.value && c.items.isEmpty) {
        return const _NewsSkeletonList();
      }
      // 只看收藏时按收藏 id 过滤。
      final favOnly = c.favOnly.value;
      final visible = favOnly
          ? c.items.where((e) => fav.ids.contains(e.id)).toList()
          : c.items.toList();

      return Column(
        children: [
          _FilterHeader(
            favOnly: favOnly,
            usingMock: c.usingMock.value,
            onChanged: (v) => c.favOnly.value = v,
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyView(
                    message: favOnly ? '还没有收藏的资讯' : '暂无资讯',
                    onRetry: () => c.refreshNews(refresh: true),
                  )
                : RefreshIndicator(
                    onRefresh: () => c.refreshNews(refresh: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _NewsEntryCard(
                        entry: visible[i],
                        onAction: (a) => _handleAction(context, a),
                      ),
                    ),
                  ),
          ),
        ],
      );
    });
  }

  void _handleAction(BuildContext context, MicroAction action) {
    handleCreativeAction(context, action);
  }
}

// ── 筛选头（全部 / 收藏 + mock 标识）────────────────────────

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.favOnly,
    required this.usingMock,
    required this.onChanged,
  });

  final bool favOnly;
  final bool usingMock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: !favOnly,
            onSelected: (_) => onChanged(false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: Icon(
              Icons.favorite,
              size: 16,
              color: favOnly ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
            label: const Text('收藏'),
            selected: favOnly,
            onSelected: (_) => onChanged(true),
          ),
          const Spacer(),
          if (usingMock)
            Container(
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
            ),
        ],
      ),
    );
  }
}

// ── 单条资讯卡（blocks 拼贴 + 右上角收藏爱心）─────────────────

class _NewsEntryCard extends StatelessWidget {
  const _NewsEntryCard({required this.entry, required this.onAction});

  final NewsEntry entry;
  final void Function(MicroAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fav = FavoritesController.to;
    return Stack(
      children: [
        BlockRenderer(blocks: entry.blocks, spacing: 10, onAction: onAction),
        Positioned(
          top: 8,
          right: 8,
          child: Obx(() {
            final isFav = fav.isFav(entry.id);
            return Material(
              color: Colors.black.withValues(alpha: 0.32),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: isFav ? '取消收藏' : '收藏',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? cs.error : Colors.white,
                ),
                onPressed: () => fav.toggle(
                  entry.id,
                  title: entry.title,
                  cover: entry.cover,
                  type: 'news',
                ),
              ),
            );
          }),
        ),
      ],
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
