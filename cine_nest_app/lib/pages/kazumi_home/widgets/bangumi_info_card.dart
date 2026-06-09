import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';

class BangumiInfoCardV extends StatelessWidget {
  const BangumiInfoCardV({
    super.key,
    required this.item,
    this.isLoading = false,
  });

  final TmdbMediaItem item;
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
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: LayoutBuilder(builder: (context, box) {
                      return Hero(
                        transitionOnUserGestures: true,
                        flightShuttleBuilder:
                            NetworkImgLayer.heroFlightShuttleBuilder,
                        tag: 'kazumi_cover_${item.id}',
                        child: NetworkImgLayer(
                          src: item.poster(),
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
                            const Text('上映日期:'),
                            Text(
                              item.releaseDate.isEmpty
                                  ? '未知'
                                  : item.releaseDate,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${item.voteCount} 人评分:'),
                            Row(
                              children: [
                                Text(
                                  item.voteAverage.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...List.generate(5, (i) {
                                  final fill = item.voteAverage / 2;
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
                            const Text('类型:'),
                            Text(
                              item.mediaType == 'tv' ? '剧集' : '电影',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 120,
                          height: 40,
                          child: FilledButton.tonalIcon(
                            onPressed: () {},
                            icon: const Icon(Icons.favorite_border, size: 18),
                            label: const Text('收藏'),
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
