import 'package:flutter/material.dart';

class ForumVisual extends StatelessWidget {
  const ForumVisual({
    super.key,
    this.imageUrl,
    this.sticker,
    this.compact = false,
  });

  final String? imageUrl;
  final String? sticker;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final images = _parseImages(imageUrl);
    final emoji = sticker?.trim() ?? '';
    if (images.isEmpty && emoji.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) _ImageBlock(images: images, compact: compact),
        if (emoji.isNotEmpty) ...[
          SizedBox(height: images.isEmpty ? 0 : 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xfffff4d8),
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 30 : 44, height: 1.1),
            ),
          ),
        ],
      ],
    );
  }

  List<String> _parseImages(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return const [];
    return value
        .split(RegExp(r'[|,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(9)
        .toList();
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.images, required this.compact});

  final List<String> images;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: compact ? 1.45 : 1.12,
          child: _ForumImage(raw: images.first),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _ForumImage(raw: images[index]),
      ),
    );
  }
}

class _ForumImage extends StatelessWidget {
  const _ForumImage({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    if (raw.startsWith('asset:')) {
      return Image.asset(
        'assets/${raw.substring('asset:'.length)}',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _BrokenImage(),
      );
    }

    return Image.network(
      raw,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _BrokenImage(),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_filter_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 38,
      ),
    );
  }
}
