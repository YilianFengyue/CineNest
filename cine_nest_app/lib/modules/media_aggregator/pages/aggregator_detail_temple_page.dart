import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../models/media_models.dart';
import '../services/aggregator_detail_engine.dart';
import '../widgets/episode_grid.dart';
import 'aggregator_player_host_page.dart';

class AggregatorDetailTemplePage extends StatefulWidget {
  const AggregatorDetailTemplePage({super.key});

  @override
  State<AggregatorDetailTemplePage> createState() =>
      _AggregatorDetailTemplePageState();
}

class _AggregatorDetailTemplePageState
    extends State<AggregatorDetailTemplePage> {
  final _engine = AggregatorDetailEngine();
  late final AggregatorSearchResult _seed;
  late final Future<AggregatorMediaDetail> _future;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is AggregatorSearchResult) {
      _seed = args;
    } else if (args is Map) {
      _seed = AggregatorSearchResult.fromJson(Map<String, dynamic>.from(args));
    } else {
      throw StateError('缺少聚合器详情参数');
    }
    _future = _engine.loadDetail(_seed);
  }

  Future<void> _play(AggregatorMediaDetail detail, int index) async {
    try {
      SmartDialog.showLoading(msg: '正在探测播放地址');
      final session = await _engine.buildPlaySession(
        detail,
        episodeIndex: index,
      );
      SmartDialog.dismiss();
      Get.to(() => AggregatorPlayerHostPage(session: session));
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(_friendly(e));
    }
  }

  String _friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('未找到可播放直链')) return '未找到可播放直链，建议换源';
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聚合器详情 Temple')),
      body: FutureBuilder<AggregatorMediaDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_friendly(snapshot.error!)),
              ),
            );
          }
          final detail = snapshot.requireData;
          return Column(
            children: [
              _Header(detail: detail),
              const Divider(height: 1),
              Expanded(
                child: EpisodeGrid(
                  episodes: detail.episodes
                      .where((episode) => episode.isPlayableDirectUrl)
                      .toList(),
                  onTap: (index) => _play(detail, index),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final AggregatorMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 92,
              height: 132,
              child: detail.bestPoster == null
                  ? ColoredBox(color: cs.surfaceContainerHighest)
                  : CachedNetworkImage(
                      imageUrl: detail.bestPoster!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${detail.sourceName} · ${detail.year ?? '年份未知'} · ${detail.episodes.length} 集',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail.tmdb?.overview?.isNotEmpty == true
                      ? detail.tmdb!.overview!
                      : (detail.desc?.isNotEmpty == true
                            ? detail.desc!
                            : '暂无简介'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
