import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cine_nest/pages/kazumi_home/mock_data.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';

class BangumiInfoCardV extends StatelessWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    this.isLoading = false,
  });

  final MockBangumiItem bangumiItem;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 左侧封面 ──
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: LayoutBuilder(builder: (context, box) {
                      return Hero(
                        transitionOnUserGestures: true,
                        flightShuttleBuilder:
                            NetworkImgLayer.heroFlightShuttleBuilder,
                        tag: 'kazumi_cover_${bangumiItem.id}',
                        child: NetworkImgLayer(
                          src: bangumiItem.imageUrl,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                // ── 右侧元数据 ──
                Flexible(
                  child: Skeletonizer(
                    enabled: isLoading,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('放送开始:'),
                            Text(
                              bangumiItem.airDate.isEmpty
                                  ? '2000-11-11'
                                  : bangumiItem.airDate,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${bangumiItem.votes} 人评分:'),
                            Row(
                              children: [
                                Text(
                                  '${bangumiItem.ratingScore}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...List.generate(5, (i) {
                                  final fill = bangumiItem.ratingScore / 2;
                                  return Icon(
                                    i < fill.floor()
                                        ? Icons.star_rounded
                                        : (i < fill
                                            ? Icons.star_half_rounded
                                            : Icons.star_outline_rounded),
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Bangumi Ranked:'),
                            Text(
                              '#${bangumiItem.rank}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        // ── 收藏按钮 ──
                        SizedBox(
                          width: 120,
                          height: 40,
                          child: FilledButton.tonalIcon(
                            onPressed: () {},
                            icon: const Icon(Icons.favorite_border, size: 18),
                            label: const Text('未追'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
