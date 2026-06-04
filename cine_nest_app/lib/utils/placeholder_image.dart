import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';

/// 统一封面 / 占位图（成员 C）。
///
/// 背景：豆瓣封面带 Referer 防盗链、AI 生图偶发失败、后端字段缺失，
/// 都会导致真实图加载不出来。以前一律显示灰块，观感很差。
///
/// 这里的约定：**任何封面位永远有图**——真实图为空或加载失败时，
/// 退回一张「按 seed 取的随机占位图」（picsum，按 seed 稳定取图，
/// 同一条目每次同图，不会闪来闪去）。只有占位图也挂了才显示图标兜底。

/// 生成稳定的随机占位图 URL。
///
/// 用 [seed]（一般传片名 / url）决定取哪张，保证同一条目每次同一张图；
/// picsum.photos 在国内可达，替代已下线的 source.unsplash.com。
String placeholderImageUrl(String seed, {int width = 400, int height = 600}) {
  final s = seed.trim().isEmpty ? 'cinenest' : seed.trim();
  return 'https://picsum.photos/seed/${Uri.encodeComponent(s)}/$width/$height';
}

/// 通用封面图组件：空 / 失败自动退回随机占位图，绝不留空灰块。
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.seed = '',
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  /// 真实图 URL（可空、可相对 `/api/assets/..`，由 [mediaUrl] 补全）。
  final String url;

  /// 占位图取图种子（建议传片名，保证稳定）；为空时用 [url] 兜底。
  final String seed;

  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = placeholderImageUrl(seed.isEmpty ? url : seed);
    final resolved = url.trim().isEmpty ? fallback : mediaUrl(url);

    Widget loading() => Container(color: cs.surfaceContainerHighest);
    Widget broken() => Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.movie_outlined, color: cs.outline),
    );

    return CachedNetworkImage(
      imageUrl: resolved,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, _) => loading(),
      // 真实图失败 → 再试占位图；占位图也挂 → 图标兜底。
      errorWidget: (_, _, _) => CachedNetworkImage(
        imageUrl: fallback,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, _) => loading(),
        errorWidget: (_, _, _) => broken(),
      ),
    );
  }
}
