import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/bilibili_service.dart';

/// PiliPlus VideoCardH 风格的 B 站视频卡片。
class BiliVideoCard extends StatelessWidget {
  const BiliVideoCard({super.key, required this.video});

  final BiliVideo video;

  Future<void> _onTap() async {
    // 直接尝试 bilibili:// scheme 唤起 APP，不用 canLaunchUrl（对自定义 scheme 不可靠）
    if (video.appUrl.isNotEmpty) {
      try {
        final ok = await launchUrl(
          Uri.parse(video.appUrl),
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (ok) return;
      } catch (_) {}
    }
    if (video.fallbackUrl.isNotEmpty) {
      await launchUrl(
        Uri.parse(video.fallbackUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面 16:10
              SizedBox(
                width: 160,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: video.cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 28),
                          ),
                        ),
                        // 时长角标
                        if (video.duration.isNotEmpty)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                video.duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // 右侧信息
              Expanded(
                child: SizedBox(
                  height: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.42,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                      // 日期 + UP 主
                      Text(
                        [
                          if (video.pubdate.isNotEmpty) video.pubdate,
                          if (video.author.isNotEmpty) video.author,
                        ].join('  '),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 12,
                          color: outline,
                          height: 1,
                        ),
                      ),

                      const SizedBox(height: 3),

                      // 播放量 + 弹幕
                      Row(
                        children: [
                          Icon(Icons.play_circle_outlined,
                              size: 13,
                              color: outline.withValues(alpha: 0.8)),
                          const SizedBox(width: 2),
                          Text(
                            _numFormat(video.play),
                            style: TextStyle(
                              fontSize: 12,
                              color: outline.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.subtitles_outlined,
                              size: 13,
                              color: outline.withValues(alpha: 0.8)),
                          const SizedBox(width: 2),
                          Text(
                            _numFormat(video.danmaku),
                            style: TextStyle(
                              fontSize: 12,
                              color: outline.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _numFormat(int n) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(1)}亿';
    } else if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return n.toString();
  }
}
