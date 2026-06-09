import 'package:flutter/material.dart';
import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';

class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.item,
    this.onTap,
  });

  final TmdbMediaItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
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
                  ),
                );
              }),
            ),
            _CardTitle(item: item),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.item});

  final TmdbMediaItem item;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          item.title,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: ts.clamp(maxScaleFactor: 1.1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
