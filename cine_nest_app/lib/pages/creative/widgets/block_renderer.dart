import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/creative/widgets/blocks.dart';
import 'package:cine_nest/pages/creative/widgets/cards.dart';
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
    this.onAction,
  });

  final List<ContentBlock> blocks;
  final double spacing;

  /// 视频条点击回调（无 [onAction] 时的简化入口；后续接成员 A 的播放器）。
  final void Function(ContentBlock block)? onVideoTap;

  /// 区块动作回调 —— 收到 block 自带的 [MicroAction]（openPoster / resolveAndPlay 等）。
  /// 优先级高于 [onVideoTap]：海报页 / 对话卡用它把点击派发给统一的 action 分发器。
  final void Function(MicroAction action)? onAction;

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

  /// 把一个块的点击统一收敛：优先派发它自带的 action，否则回退到 onVideoTap。
  VoidCallback? _tapFor(ContentBlock block) {
    final action = block.action;
    if (action != null && !action.isEmpty && onAction != null) {
      return () => onAction!(action);
    }
    if (onVideoTap != null) return () => onVideoTap!(block);
    return null;
  }

  Widget? _render(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.banner:
        return BannerBlock(block);
      case ContentBlockType.heading:
        return HeadingBlock(block);
      case ContentBlockType.text:
        return TextBlock(block);
      case ContentBlockType.tagRow:
        return TagRowBlock(block);
      case ContentBlockType.imageSwiper:
        return ImageSwiperBlock(block);
      case ContentBlockType.videoBar:
        return VideoBarBlock(block, onTap: _tapFor(block));
      case ContentBlockType.posterRow:
        return PosterRowBlock(block, onTap: _tapFor(block));
      case ContentBlockType.rating:
        return RatingBlock(block);
      // ── v1.1 富交互卡 ──
      case ContentBlockType.playableMovieCard:
        return PlayableMovieCard(block, onAction: onAction);
      case ContentBlockType.movieCarousel:
        return MovieCarouselCard(block, onAction: onAction);
      case ContentBlockType.reviewQuoteCard:
        return ReviewQuoteCard(block);
      case ContentBlockType.sourceTraceCard:
        return SourceTraceCard(block);
      case ContentBlockType.newsCard:
        return NewsCardBlock(block, onAction: onAction);
      case ContentBlockType.mediaGallery:
        return MediaGalleryCard(block);
      case ContentBlockType.videoExplainCard:
        return VideoExplainCard(block, onAction: onAction);
      case ContentBlockType.unknown:
        return null; // 前向兼容：后端新增 type 时静默跳过，不崩
    }
  }
}
