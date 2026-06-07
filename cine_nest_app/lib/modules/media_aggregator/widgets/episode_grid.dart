import 'package:flutter/material.dart';

import '../models/media_models.dart';

class EpisodeGrid extends StatelessWidget {
  const EpisodeGrid({super.key, required this.episodes, required this.onTap});

  final List<AggregatorEpisode> episodes;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const Center(child: Text('未找到可播放集数'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.3,
      ),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        return OutlinedButton(
          onPressed: () => onTap(index),
          child: Text(
            episode.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
