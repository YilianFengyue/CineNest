import 'package:cine_nest/pages/creative/news/news_card.dart';
import 'package:cine_nest/pages/creative/news/news_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 资讯 Tab 页（F12）—— 图文卡片流 + 下拉刷新 + 骨架屏。
///
/// 数据来自 [NewsController]，每张卡通过 `BlockRenderer` 把后端区块拼贴成图文卡。
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(NewsController());
    return Obx(() {
      if (c.loading.value && c.items.isEmpty) {
        return const _NewsSkeletonList();
      }
      return RefreshIndicator(
        onRefresh: c.refreshNews,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: c.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => NewsCard(c.items[i]),
        ),
      );
    });
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
            _PulseBox(height: 12, widthFactor: 1),
            SizedBox(height: 8),
            _PulseBox(height: 12, widthFactor: 0.7),
            SizedBox(height: 16),
            _PulseBox(height: 124, widthFactor: 1, radius: 10),
          ],
        ),
      ),
    );
  }
}

/// 呼吸式占位块 —— tonal 表面在两档 container 色之间缓慢插值，避免「死灰块」。
class _PulseBox extends StatefulWidget {
  const _PulseBox({
    this.widthFactor,
    required this.height,
    this.radius = 6,
  });

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
