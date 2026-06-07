import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/media_models.dart';
import 'source_health_chip.dart';

class AggregatorMediaCard extends StatelessWidget {
  const AggregatorMediaCard({
    super.key,
    required this.item,
    required this.onDetail,
    required this.onPlay,
  });

  final AggregatorSearchResult item;
  final VoidCallback onDetail;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: onDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(url: item.bestPoster, title: item.title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(text: item.sourceName),
                        if (item.year?.isNotEmpty == true)
                          _Tag(text: item.year!),
                        if (item.episodeCount > 0)
                          _Tag(text: '${item.episodeCount} 集'),
                        if (item.hasPlayableDirectUrl)
                          const _Tag(text: '直链', important: true),
                        SourceHealthChip(health: item.health),
                      ],
                    ),
                    if ((item.remarks ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.remarks!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onDetail,
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('详情'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonalIcon(
                          onPressed: item.hasPlayableDirectUrl ? onPlay : null,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('试播'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 78,
        height: 112,
        child: url == null || url!.isEmpty
            ? _Placeholder(title: title)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: 180,
                placeholder: (_, _) =>
                    ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => _Placeholder(title: title),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        _shortTitle(title),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _shortTitle(String value) {
    final chars = value.characters.take(4).toList();
    return chars.isEmpty ? '影片' : chars.join();
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.important = false});

  final String text;
  final bool important;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = important ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
