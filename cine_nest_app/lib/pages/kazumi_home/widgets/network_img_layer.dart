import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const Radius _kImgRadius = Radius.circular(12);

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.filterQuality = FilterQuality.high,
    this.color,
    this.colorBlendMode,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;

  static Widget heroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;
    final hero = (flightDirection == HeroFlightDirection.push
        ? fromHeroContext.widget
        : toHeroContext.widget) as Hero;

    return InheritedTheme.captureAll(
      heroContext,
      Material(type: MaterialType.transparency, child: hero.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = src ?? '';

    if (imageUrl.isEmpty) return placeholder(context);

    final borderRadius = BorderRadius.all(
      type == 'avatar' ? const Radius.circular(50) : _kImgRadius,
    );

    return ClipRRect(
      clipBehavior: Clip.antiAlias,
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 120),
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 120),
        filterQuality: filterQuality,
        color: color,
        colorBlendMode: colorBlendMode,
        errorWidget: (_, __, ___) => placeholder(context),
        placeholder: (_, __) => placeholder(context),
      ),
    );
  }

  Widget placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.all(
          type == 'avatar' ? const Radius.circular(50) : _kImgRadius,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
