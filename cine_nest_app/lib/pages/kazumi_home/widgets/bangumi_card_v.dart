import 'package:flutter/material.dart';
import 'package:cine_nest/pages/kazumi_home/mock_data.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';

class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.onTap,
  });

  final MockBangumiItem bangumiItem;
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
                  tag: 'kazumi_cover_${bangumiItem.id}',
                  child: NetworkImgLayer(
                    src: bangumiItem.imageUrl,
                    width: box.maxWidth,
                    height: box.maxHeight,
                  ),
                );
              }),
            ),
            _BangumiContent(bangumiItem: bangumiItem),
          ],
        ),
      ),
    );
  }
}

class _BangumiContent extends StatelessWidget {
  const _BangumiContent({required this.bangumiItem});

  final MockBangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          bangumiItem.nameCn,
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
