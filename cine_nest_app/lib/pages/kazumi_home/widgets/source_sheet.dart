import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';
import 'package:cine_nest/modules/media_aggregator/services/aggregator_detail_engine.dart';
import 'package:cine_nest/modules/media_aggregator/services/aggregator_search_engine.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_player_page.dart';
import 'package:cine_nest/services/tmdb_direct_enrichment_service.dart';

class SourceSheet extends StatefulWidget {
  const SourceSheet({super.key, required this.title, this.year});

  final String title;
  final String? year;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet> {
  final _enrichment = TmdbDirectEnrichmentService();
  late final AggregatorSearchEngine _searchEngine;
  late final AggregatorDetailEngine _detailEngine;

  StreamSubscription<AggregatorSearchBatch>? _sub;
  final _results = <AggregatorSearchResult>[];
  int _completed = 0;
  int _total = 0;
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _searchEngine = AggregatorSearchEngine(
      enableTmdbEnrichment: true,
      enrichmentService: _enrichment,
    );
    _detailEngine = AggregatorDetailEngine(enrichmentService: _enrichment);
    _startSearch();
  }

  void _startSearch() {
    _sub = _searchEngine
        .search(widget.title)
        .listen(
          (batch) {
            if (!mounted) return;
            setState(() {
              _results
                ..clear()
                ..addAll(batch.results);
              _completed = batch.completedSources;
              _total = batch.totalSources;
              _searching = batch.searching;
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _searching = false);
          },
        );
  }

  Future<void> _play(AggregatorSearchResult result) async {
    try {
      SmartDialog.showLoading(msg: '正在加载详情');
      final detail = await _detailEngine.loadDetail(result, enrichTmdb: true);
      final session = await _detailEngine.buildPlaySession(detail);
      SmartDialog.dismiss();
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.to(() => KazumiPlayerPage(session: session, detail: detail));
    } catch (e) {
      SmartDialog.dismiss();
      final msg = e.toString();
      if (msg.contains('未找到可播放直链')) {
        SmartDialog.showToast('未找到可播放直链，建议换源');
      } else {
        SmartDialog.showToast('加载失败，建议换源');
      }
    }
  }

  Future<void> _detail(AggregatorSearchResult result) async {
    try {
      SmartDialog.showLoading(msg: '正在加载详情');
      final detail = await _detailEngine.loadDetail(result, enrichTmdb: true);
      SmartDialog.dismiss();
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.to(() => KazumiPlayerPage(session: null, detail: detail));
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('详情加载失败');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        // ── 标题栏 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _searching ? '$_completed/$_total 源' : '${_results.length} 条结果',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: _searching ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _searching
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
        const SizedBox(height: 4),

        // ── 结果卡片列表 ──
        Expanded(child: _buildResultList(theme, cs)),
      ],
    );
  }

  Widget _buildResultList(ThemeData theme, ColorScheme cs) {
    if (_results.isEmpty && !_searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('未找到可播放源', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SourceCard(
        result: _results[i],
        onPlay: () => _play(_results[i]),
        onDetail: () => _detail(_results[i]),
      ),
    );
  }
}

// ── 搜索结果卡片（Material You）──
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.result,
    required this.onPlay,
    required this.onDetail,
  });

  final AggregatorSearchResult result;
  final VoidCallback onPlay;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final poster = result.bestPoster;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetail,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 封面（固定宽，高度撑满卡片）──
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 92,
                  child: poster != null
                      ? CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _PosterPlaceholder(cs: cs),
                        )
                      : _PosterPlaceholder(cs: cs),
                ),
              ),

              // ── 信息区（右侧撑满）──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(label: result.sourceName, cs: cs),
                          if (result.year != null)
                            _Chip(label: result.year!, cs: cs),
                          _Chip(label: '${result.episodeCount} 集', cs: cs),
                          if (result.hasPlayableDirectUrl)
                            _Chip(label: '直链', cs: cs, accent: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (result.remarks?.isNotEmpty == true)
                        Text(
                          result.remarks!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          // 使用 Expanded 让按钮撑满可用宽度
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.info_outline,
                              label: '详情',
                              onTap: onDetail,
                              cs: cs,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 同样使用 Expanded
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.play_arrow_rounded,
                              label: '观看',
                              onTap: onPlay,
                              cs: cs,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 28),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.cs, this.accent = false});
  final String label;
  final ColorScheme cs;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: accent ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
