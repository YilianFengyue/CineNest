import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';
import 'package:cine_nest/modules/media_aggregator/services/aggregator_detail_engine.dart';
import 'package:cine_nest/pages/player_kazumi/controller/player_controller.dart';
import 'package:cine_nest/pages/player_kazumi/services/kazumi_audio_handler.dart';
import 'package:cine_nest/pages/player_kazumi/services/pip_service.dart';
import 'package:cine_nest/pages/player_kazumi/services/screenshot_service.dart';
import 'package:cine_nest/pages/player_kazumi/widgets/kazumi_player_view.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/repositories/local_history_repository.dart';
import 'package:cine_nest/services/tmdb_direct_enrichment_service.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/debate_recommendation_card.dart';

class KazumiPlayerPage extends StatefulWidget {
  const KazumiPlayerPage({
    super.key,
    required this.session,
    required this.detail,
  });

  final AggregatorPlaySession? session;
  final AggregatorMediaDetail detail;

  @override
  State<KazumiPlayerPage> createState() => _KazumiPlayerPageState();
}

class _KazumiPlayerPageState extends State<KazumiPlayerPage>
    with SingleTickerProviderStateMixin {
  late final KazumiPlayerController _ctrl;
  late final AggregatorDetailEngine _detailEngine;
  late final TabController _tabCtrl;
  KazumiAudioHandler? _audioHandler;
  Worker? _errorWorker;
  String _lastShownError = '';

  final _historyRepo = LocalHistoryRepository();
  late AggregatorPlaySession? _session;
  late List<AggregatorEpisode> _playable;
  int _currentIndex = 0;

  String get _tag =>
      'kz_player_${widget.detail.source}_${widget.detail.remoteId}';

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _detailEngine = AggregatorDetailEngine(
      enrichmentService: TmdbDirectEnrichmentService(),
    );
    _playable = widget.detail.episodes
        .where((e) => e.isPlayableDirectUrl)
        .toList();
    _tabCtrl = TabController(length: 2, vsync: this);

    if (_session != null) {
      _currentIndex = _session!.episodeIndex.clamp(0, _playable.length - 1);
    }

    _ctrl = KazumiPlayerController(
      firstFrameTimeout: const Duration(seconds: 8),
    );
    Get.put(_ctrl, tag: _tag, permanent: false);

    _errorWorker = ever<String>(_ctrl.lastError, (error) {
      if (error.isEmpty || error == _lastShownError) return;
      _lastShownError = error;
      SmartDialog.showToast(_friendlyError(error));
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _audioHandler = await ensureKazumiAudioHandler();
    _audioHandler?.attach(_ctrl);
    if (_session != null) {
      _audioHandler?.setMediaInfo(title: _session!.title);
      await _openCurrent();
    }
  }

  Future<void> _openCurrent() async {
    if (_session == null) return;
    await _ctrl.open(
      url: _session!.playUrl,
      headers: _session!.headers,
      startAt: _session!.resumePosition,
    );
  }

  Future<void> _playEpisode(int index) async {
    if (index < 0 || index >= _playable.length) return;
    _saveHistory();
    try {
      final session = await _detailEngine.buildPlaySession(
        widget.detail,
        episodeIndex: index,
      );
      setState(() {
        _session = session;
        _currentIndex = index;
      });
      _audioHandler?.setMediaInfo(title: session.title);
      _lastShownError = '';
      await _ctrl.open(url: session.playUrl, headers: session.headers);
    } catch (e) {
      SmartDialog.showToast('播放失败，建议换源');
    }
  }

  void _openInWebView() {
    if (_session == null) return;
    Get.toNamed(
      Routes.webviewPlayer,
      arguments: {'url': _session!.playUrl, 'title': _session!.title},
    );
  }

  Future<void> _doScreenshot() async {
    final result = await ScreenshotService.captureAndSave(_ctrl);
    SmartDialog.showToast(
      result.ok ? '截图已保存到相册' : (result.errorMessage ?? '保存失败'),
    );
  }

  Future<void> _doPip() async {
    final ok = await PipService.enter();
    if (!ok) SmartDialog.showToast('当前平台不支持小窗模式');
  }

  void _saveHistory() {
    if (_session == null) return;
    final ep = _currentIndex < _playable.length
        ? _playable[_currentIndex]
        : null;
    _historyRepo.save(
      HistoryRecord(
        id: widget.detail.remoteId,
        title: widget.detail.title,
        cover: widget.detail.bestPoster,
        year: widget.detail.year,
        source: widget.detail.source,
        sourceName: widget.detail.sourceName,
        episodeName: ep?.name,
        episodeIndex: _currentIndex,
        positionMs: _ctrl.position.value.inMilliseconds,
        durationMs: _ctrl.duration.value.inMilliseconds,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void dispose() {
    _saveHistory();
    _tabCtrl.dispose();
    _errorWorker?.dispose();
    _audioHandler?.detach();
    Get.delete<KazumiPlayerController>(tag: _tag);
    super.dispose();
  }

  String _friendlyError(String raw) {
    if (raw.contains('超时') || raw.contains('TimeoutException')) {
      return '起播超时，可重试或返回换源';
    }
    if (raw.contains('403') || raw.contains('401')) return '源鉴权失败';
    return raw.length > 100 ? '${raw.substring(0, 100)}...' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fullscreen = _ctrl.isFullscreen.value;
      return PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && fullscreen) _ctrl.setFullscreen(false);
        },
        child: Scaffold(
          backgroundColor: fullscreen
              ? Colors.black
              : Theme.of(context).colorScheme.surface,
          body: fullscreen
              ? _buildPlayer(fullscreen: true)
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // ── 播放器（固定顶部，不随滚动）──
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _session != null
                            ? _buildPlayer(fullscreen: false)
                            : const ColoredBox(
                                color: Colors.black,
                                child: Center(
                                  child: Text(
                                    '选择剧集开始播放',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              ),
                      ),
                      // ── TabBar ──
                      Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: TabBar(
                          controller: _tabCtrl,
                          tabs: const [
                            Tab(text: '简介'),
                            Tab(text: '评论'),
                          ],
                          dividerHeight: 0.5,
                        ),
                      ),
                      // ── Tab 内容 ──
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _InfoTab(
                              detail: widget.detail,
                              playable: _playable,
                              currentIndex: _currentIndex,
                              onPlayEpisode: _playEpisode,
                            ),
                            DebateRecommendationCard(
                              detail: widget.detail,
                              episodeName: _currentIndex < _playable.length
                                  ? _playable[_currentIndex].name
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildPlayer({required bool fullscreen}) {
    return KazumiPlayerView(
      controller: _ctrl,
      title: _session?.title ?? widget.detail.title,
      onBack: fullscreen
          ? () => _ctrl.setFullscreen(false)
          : () => Navigator.of(context).maybePop(),
      onScreenshot: _doScreenshot,
      onEnterPip: _doPip,
      onRetry: _openCurrent,
      onOpenInWebView: _openInWebView,
    );
  }
}

// ── 简介 Tab ──
class _InfoTab extends StatefulWidget {
  const _InfoTab({
    required this.detail,
    required this.playable,
    required this.currentIndex,
    required this.onPlayEpisode,
  });

  final AggregatorMediaDetail detail;
  final List<AggregatorEpisode> playable;
  final int currentIndex;
  final ValueChanged<int> onPlayEpisode;

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  final _favRepo = LocalFavoriteRepository();
  late bool _isFav;

  AggregatorMediaDetail get detail => widget.detail;
  List<AggregatorEpisode> get playable => widget.playable;
  int get currentIndex => widget.currentIndex;
  ValueChanged<int> get onPlayEpisode => widget.onPlayEpisode;

  @override
  void initState() {
    super.initState();
    _isFav = _favRepo.isFavorite('${detail.source}:${detail.remoteId}');
  }

  Future<void> _toggleFav() async {
    await _favRepo.toggle(
      FavoriteRecord(
        id: detail.remoteId,
        title: detail.title,
        cover: detail.bestPoster,
        year: detail.year,
        source: detail.source,
        sourceName: detail.sourceName,
        episodeCount: playable.length,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    setState(() => _isFav = !_isFav);
  }

  void _showEpisodeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top -
            (MediaQuery.of(context).size.width * 9 / 16),
      ),
      builder: (_) => _EpisodeSheet(
        playable: playable,
        currentIndex: currentIndex,
        onPlay: (i) {
          Navigator.of(context).pop();
          onPlayEpisode(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── 标题 + 追剧 ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      detail.sourceName,
                      if (detail.year != null) detail.year,
                      '${playable.length} 集',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: _toggleFav,
              icon: Icon(
                _isFav ? Icons.favorite : Icons.favorite_border,
                size: 18,
              ),
              label: Text(_isFav ? '已追剧' : '追剧'),
            ),
          ],
        ),

        // ── 简介 ──
        if (_desc.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _desc,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── 合集头 ──
        if (playable.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '合集',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '正在播放: ${playable[currentIndex].name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (playable.length > 1)
                TextButton(
                  onPressed: () => _showEpisodeSheet(context),
                  child: Text('全${playable.length}话 >'),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── 横向选集卡片 ──
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playable.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isCurrent = i == currentIndex;
                return _EpisodeTile(
                  index: i,
                  name: playable[i].name,
                  isCurrent: isCurrent,
                  width: 120,
                  onTap: () => onPlayEpisode(i),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  String get _desc {
    if (detail.tmdb?.overview?.isNotEmpty == true) {
      return detail.tmdb!.overview!;
    }
    if (detail.desc?.isNotEmpty == true) return detail.desc!;
    return '';
  }
}

// ── 展开选集 Sheet（顶到播放器下方）──
class _EpisodeSheet extends StatelessWidget {
  const _EpisodeSheet({
    required this.playable,
    required this.currentIndex,
    required this.onPlay,
  });

  final List<AggregatorEpisode> playable;
  final int currentIndex;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        // ── 头部 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                '选集',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '全${playable.length}话',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 两列网格 ──
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 52,
            ),
            itemCount: playable.length,
            itemBuilder: (context, i) {
              final isCurrent = i == currentIndex;
              return _EpisodeTile(
                index: i,
                name: playable[i].name,
                isCurrent: isCurrent,
                onTap: () => onPlay(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 单个选集矩形卡片 ──
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.index,
    required this.name,
    required this.isCurrent,
    required this.onTap,
    this.width,
  });

  final int index;
  final String name;
  final bool isCurrent;
  final VoidCallback onTap;
  final double? width;

  static const _bg = Color(0xFFF2F0FB);
  static const _selectedBg = Color(0xFF5B6ABF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: isCurrent ? _selectedBg : _bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (isCurrent) ...[
                      Icon(Icons.equalizer, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Colors.white : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
