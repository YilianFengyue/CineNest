import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/poster/poster_controller.dart';
import 'package:cine_nest/pages/creative/poster/poster_export_view.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// F8 互动海报详情页 —— 一部作品的竖向交互大海报。
///
/// 头图（模糊背景 + 竖版海报 + 标题/评分）→ blocks 拼贴（剧照/影评/解说/线路…）
/// → 底部播放栏。支持「导出长图分享」。数据 mock 与真后端通用（见 [PosterController]）。
class PosterPage extends StatelessWidget {
  const PosterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PosterController());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value.isNotEmpty) {
          return _ErrorView(message: c.errorMsg.value, onRetry: c.reload);
        }
        return CustomScrollView(
          slivers: [
            _PosterHeader(c: c),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: BlockRenderer(
                  blocks: c.body,
                  spacing: 14,
                  onAction: (a) => _handleAction(context, a),
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        if (c.loading.value || c.primaryPlay == null) {
          return const SizedBox.shrink();
        }
        return _PlayBar(
          accent: c.accent(cs),
          onPlay: () => _handleAction(context, c.primaryPlay!),
        );
      }),
    );
  }

  void _handleAction(BuildContext context, MicroAction action) {
    final messenger = ScaffoldMessenger.of(context);
    switch (action.type) {
      case 'resolveAndPlay':
        // TODO(C↔A): 跳 A 的播放器 /player，或先 GET /api/sources/parse 拿 play_url。
        messenger.showSnackBar(
          const SnackBar(content: Text('播放将对接 A 的播放器（联调期接入）')),
        );
        break;
      case 'openPoster':
      case 'openResourcePoster':
        Get.toNamed('/creative-poster', arguments: action.data);
        break;
      default:
        break;
    }
  }
}

/// 头部：模糊背景 + 竖版海报 + 标题 / 副标题 / 评分；导出按钮放 AppBar。
class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.c});
  final PosterController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = c.accent(cs);
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      foregroundColor: Colors.white,
      backgroundColor: cs.surface,
      actions: [
        IconButton(
          tooltip: '导出长图分享',
          icon: const Icon(Icons.ios_share),
          onPressed: () => _PosterExporter.run(context, c),
        ),
      ],
      title: _CollapsedTitle(title: c.title),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 模糊背景
            if (c.backdrop.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: CachedNetworkImage(
                  imageUrl: c.backdrop,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Container(color: cs.surfaceContainerHighest),
                ),
              )
            else
              Container(color: cs.surfaceContainerHighest),
            // 暗化蒙层（顶部为状态栏可读，底部沉到 surface）
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.15),
                    cs.surface,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // 海报 + 信息
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      height: 138,
                      child: c.poster.isEmpty
                          ? Container(color: cs.surfaceContainerHighest)
                          : CachedNetworkImage(
                              imageUrl: c.poster,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(Icons.movie_outlined,
                                    color: cs.outline),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                        if (c.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            c.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        if (c.rating != null && c.rating! > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  c.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                if (c.ratingLabel.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    c.ratingLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 折叠后 AppBar 标题（展开时隐藏，靠 FlexibleSpaceBar 的大标题）。
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final deltaExtent = settings == null
        ? 0.0
        : settings.maxExtent - settings.minExtent;
    final t = settings == null || deltaExtent <= 0
        ? 0.0
        : (1.0 -
                (settings.currentExtent - settings.minExtent) / deltaExtent)
            .clamp(0.0, 1.0);
    // 折叠到约 70% 才显示标题，避免与大标题重叠。
    return Opacity(
      opacity: t < 0.7 ? 0.0 : (t - 0.7) / 0.3,
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// 底部播放栏。
class _PlayBar extends StatelessWidget {
  const _PlayBar({required this.accent, required this.onPlay});
  final Color accent;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: onPlay,
          style: FilledButton.styleFrom(backgroundColor: accent),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('立即播放'),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 40, color: cs.outline),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 导出长图 + 系统分享。
abstract final class _PosterExporter {
  static Future<void> run(BuildContext context, PosterController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在生成长图…'), duration: Duration(seconds: 1)),
    );
    try {
      final bytes = await ScreenshotController().captureFromLongWidget(
        buildPosterExportView(theme, c),
        pixelRatio: 2.5,
        delay: const Duration(milliseconds: 1200),
        constraints: const BoxConstraints(maxWidth: 420),
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cinenest_poster_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '我在 CineNest 发现了《${c.title}》',
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('长图生成失败，请重试')),
      );
    }
  }
}
