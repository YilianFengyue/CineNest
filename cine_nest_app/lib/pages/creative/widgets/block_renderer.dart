import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/widgets/blocks.dart';
import 'package:flutter/material.dart';

/// 区块分发器 —— 「微组件拼贴系统」的中枢。
///
/// 把 `List<ContentBlock>` 按 [ContentBlockType] 映射到对应微组件并纵向拼贴，
/// 块与块之间留 [spacing] 间距。对标 PiliPlus 动态流的 `content_panel` 分发逻辑。
///
/// F12 资讯卡 / F8 互动海报 / F9 对话推荐卡 都通过它渲染，只是喂的 blocks 不同。
class BlockRenderer extends StatelessWidget {
  const BlockRenderer({
    super.key,
    required this.blocks,
    this.spacing = 10,
    this.onVideoTap,
  });

  final List<ContentBlock> blocks;
  final double spacing;

  /// 视频条点击回调（后续接成员 A 的播放器路由）。
  final void Function(ContentBlock block)? onVideoTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final block in blocks) {
      final widget = _render(block);
      if (widget == null) continue; // 未知 / 空块跳过
      if (children.isNotEmpty) children.add(SizedBox(height: spacing));
      children.add(widget);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _render(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading:
        return HeadingBlock(block);
      case ContentBlockType.text:
        return TextBlock(block);
      case ContentBlockType.tagRow:
        return TagRowBlock(block);
      case ContentBlockType.imageSwiper:
        return ImageSwiperBlock(block);
      case ContentBlockType.videoBar:
        return VideoBarBlock(
          block,
          onTap: onVideoTap == null ? null : () => onVideoTap!(block),
        );
      case ContentBlockType.posterRow:
        return PosterRowBlock(
          block,
          onTap: onVideoTap == null ? null : () => onVideoTap!(block),
        );
      case ContentBlockType.rating:
        return RatingBlock(block);
      case ContentBlockType.unknown:
        return null; // 前向兼容：后端新增 type 时静默跳过，不崩
    }
  }
}
