import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/poster/poster_controller.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';

/// 海报「导出长图」的离屏渲染视图。
///
/// 经 `ScreenshotController.captureFromLongWidget` 离屏渲染，脱离 App 的 widget 树，
/// 因此必须自带 [MediaQuery] + [Theme] + [Material]，否则取不到主题与方向。
Widget buildPosterExportView(ThemeData theme, PosterController c) {
  final cs = theme.colorScheme;
  return MediaQuery(
    data: const MediaQueryData(),
    child: Theme(
      data: theme,
      child: Material(
        color: cs.surface,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头图 + 标题叠字
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: c.backdrop.isEmpty
                        ? Container(color: cs.surfaceContainerHighest)
                        : CachedNetworkImage(
                            imageUrl: mediaUrl(c.backdrop),
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                Container(color: cs.surfaceContainerHighest),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black, Colors.transparent],
                          stops: [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (c.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            c.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: BlockRenderer(blocks: c.body, spacing: 14),
              ),
              // 页脚水印
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Row(
                  children: [
                    Icon(Icons.movie_creation_outlined,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'CineNest · 影视互动海报',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
