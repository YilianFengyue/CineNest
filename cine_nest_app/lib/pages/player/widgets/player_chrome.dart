import 'package:cine_nest/models/video_source.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 播放器 chrome 共享的回调与当前状态。
/// `source_picker_page` 每次 build 时根据 setState 后的状态重建一个 actions。
class PlayerActions {
  PlayerActions({
    required this.title,
    required this.episodeLabel,
    required this.rate,
    required this.sources,
    required this.currentSourceId,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.switching,
    required this.onBack,
    required this.onPickSource,
    required this.onPickEpisode,
    required this.onChangeRate,
    required this.onOpenWebView,
  });

  final String title;
  final String? episodeLabel;
  final double rate;
  final List<VideoSource> sources;
  final String? currentSourceId;
  final List<VideoEpisode> episodes;
  final int currentEpisodeIndex;
  final bool switching;
  final VoidCallback onBack;
  final ValueChanged<VideoSource> onPickSource;
  final ValueChanged<VideoEpisode> onPickEpisode;
  final ValueChanged<double> onChangeRate;
  final VoidCallback? onOpenWebView;
}

List<Widget> buildTopButtonBar(BuildContext context, PlayerActions actions) {
  return [
    MaterialCustomButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: actions.onBack,
    ),
    const SizedBox(width: 4),
    Expanded(
      child: _TitleBlock(title: actions.title, badge: actions.episodeLabel),
    ),
    if (actions.onOpenWebView != null)
      MaterialCustomButton(
        icon: const Icon(Icons.public_rounded),
        onPressed: actions.onOpenWebView!,
      ),
  ];
}

List<Widget> buildBottomButtonBarInline(
  BuildContext context,
  PlayerActions actions,
) {
  return [
    const MaterialPlayOrPauseButton(),
    const SizedBox(width: 4),
    const MaterialPositionIndicator(
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
    const Spacer(),
    _SpeedButton(
      rate: actions.rate,
      onPressed: () => showSpeedSheet(context, actions),
    ),
    const MaterialFullscreenButton(icon: Icon(Icons.fullscreen_rounded)),
  ];
}

List<Widget> buildBottomButtonBarFullscreen(
  BuildContext context,
  PlayerActions actions,
) {
  final hasEpisodes = actions.episodes.length > 1;
  final hasMultipleSources = actions.sources.length > 1;
  return [
    const MaterialPlayOrPauseButton(iconSize: 26),
    if (hasEpisodes) ...[
      MaterialCustomButton(
        icon: const Icon(Icons.skip_previous_rounded),
        onPressed: () => _stepEpisode(actions, -1),
      ),
      MaterialCustomButton(
        icon: const Icon(Icons.skip_next_rounded),
        onPressed: () => _stepEpisode(actions, 1),
      ),
    ],
    const SizedBox(width: 8),
    const MaterialPositionIndicator(
      style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
    const Spacer(),
    if (hasMultipleSources)
      MaterialCustomButton(
        icon: const Icon(Icons.tune_rounded),
        onPressed: () => showSourceSheet(context, actions),
      ),
    if (hasEpisodes)
      MaterialCustomButton(
        icon: const Icon(Icons.playlist_play_rounded),
        onPressed: () => showEpisodeSheet(context, actions),
      ),
    _SpeedButton(
      rate: actions.rate,
      onPressed: () => showSpeedSheet(context, actions),
    ),
    const MaterialFullscreenButton(icon: Icon(Icons.fullscreen_exit_rounded)),
  ];
}

void _stepEpisode(PlayerActions actions, int delta) {
  final next = actions.currentEpisodeIndex + delta;
  if (next < 0 || next >= actions.episodes.length) return;
  actions.onPickEpisode(actions.episodes[next]);
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.badge});
  final String title;
  final String? badge;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (badge != null && badge!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.rate, required this.onPressed});
  final double rate;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final label = rate == 1.0 ? '倍速' : '${_formatRate(rate)}x';
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(48, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

String _formatRate(double rate) {
  if (rate.truncateToDouble() == rate) return rate.toStringAsFixed(0);
  final s = rate.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

const _kRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

Future<void> showSpeedSheet(BuildContext context, PlayerActions actions) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '播放速度',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            for (final r in _kRates)
              _SpeedTile(
                rate: r,
                selected: r == actions.rate,
                onTap: () {
                  actions.onChangeRate(r);
                  Navigator.of(sheetContext).maybePop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> showEpisodeSheet(BuildContext context, PlayerActions actions) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    showDragHandle: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (innerContext, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '选集',
                      style: Theme.of(innerContext).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '共 ${actions.episodes.length} 集',
                      style: Theme.of(innerContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final cols = constraints.maxWidth > 600 ? 8 : 4;
                    return GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: actions.episodes.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.9,
                      ),
                      itemBuilder: (ctx, i) {
                        final ep = actions.episodes[i];
                        final selected = i == actions.currentEpisodeIndex;
                        return FilledButton.tonal(
                          onPressed: actions.switching
                              ? null
                              : () {
                                  actions.onPickEpisode(ep);
                                  Navigator.of(sheetContext).maybePop();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: selected
                                ? Theme.of(ctx).colorScheme.primary
                                : null,
                            foregroundColor: selected
                                ? Theme.of(ctx).colorScheme.onPrimary
                                : null,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            ep.title.isEmpty ? '第${i + 1}集' : ep.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showSourceSheet(BuildContext context, PlayerActions actions) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    showDragHandle: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (innerContext, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '切换播放源',
                      style: Theme.of(innerContext).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '共 ${actions.sources.length} 个',
                      style: Theme.of(innerContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: actions.sources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final src = actions.sources[i];
                    final selected = src.id == actions.currentSourceId;
                    final cs = Theme.of(ctx).colorScheme;
                    final tags = <String>[
                      _sourceTypeLabel(src.type),
                      if ((src.quality ?? '').isNotEmpty) src.quality!,
                      if (src.type == SourceType.bilibili) '浏览器',
                    ];
                    return ListTile(
                      selected: selected,
                      selectedTileColor:
                          cs.primaryContainer.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected ? cs.primary : Colors.transparent,
                        ),
                      ),
                      leading: Icon(
                        src.type == SourceType.bilibili
                            ? Icons.ondemand_video_rounded
                            : Icons.play_circle_outline_rounded,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        src.name.isEmpty ? src.id : src.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        tags.join(' · '),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: cs.primary)
                          : null,
                      onTap: actions.switching
                          ? null
                          : () {
                              actions.onPickSource(src);
                              Navigator.of(sheetContext).maybePop();
                            },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

String _sourceTypeLabel(SourceType t) => switch (t) {
      SourceType.bilibili => 'Bilibili',
      SourceType.netdisk => '网盘',
      SourceType.web => '影视站',
    };

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({
    required this.rate,
    required this.selected,
    required this.onTap,
  });

  final double rate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        rate == 1.0 ? '1.0x（正常）' : '${_formatRate(rate)}x',
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : null,
        ),
      ),
      trailing: selected ? Icon(Icons.check_rounded, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
