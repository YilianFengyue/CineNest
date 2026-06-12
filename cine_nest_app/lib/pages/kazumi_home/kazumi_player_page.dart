import 'dart:async';

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
import 'package:cine_nest/services/cast_service.dart';
import 'package:cine_nest/services/dandanplay_service.dart';
import 'package:cine_nest/services/logvar_danmu_service.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:cine_nest/services/tmdb_direct_enrichment_service.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bili_video_section.dart';
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
  Worker? _danmakuWorker;
  Timer? _historySaveTimer;

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
    _ctrl.loadDanmakuPrefs();
    Get.put(_ctrl, tag: _tag, permanent: false);

    // 错误展示统一走播放器内的 chip/卡片（KazumiPlayerView），不再叠加 toast

    _danmakuWorker = ever<int>(_ctrl.danmakuCount, (count) {
      if (count > 0) {
        SmartDialog.showToast('已加载 $count 条弹幕');
      }
    });

    // 周期性落盘观看进度，进程被系统杀掉也不至于丢整段进度
    _historySaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_ctrl.position.value > Duration.zero) _saveHistory();
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _audioHandler = await ensureKazumiAudioHandler();
    _audioHandler?.attach(_ctrl);
    _audioHandler?.onSkipToNext = () {
      if (_currentIndex < _playable.length - 1) _playEpisode(_currentIndex + 1);
    };
    _audioHandler?.onSkipToPrevious = () {
      if (_currentIndex > 0) _playEpisode(_currentIndex - 1);
    };
    if (_session != null) {
      _updateMediaInfo(_session!.title);
      await _openCurrent();
    }
  }

  void _updateMediaInfo(String title) {
    final cover = widget.detail.bestPoster;
    _audioHandler?.setMediaInfo(
      title: title,
      artUri: cover != null && cover.isNotEmpty ? Uri.tryParse(cover) : null,
    );
  }

  Future<void> _openCurrent() async {
    if (_session == null) return;
    await _ctrl.open(
      url: _session!.playUrl,
      headers: _session!.headers,
      startAt: _session!.resumePosition,
    );
    _fetchDanmaku();
  }

  void _fetchDanmaku() {
    if (!_ctrl.danmakuVisible.value) return;
    final tmdbId = widget.detail.tmdb?.tmdbId;
    _ctrl.fetchDanmaku(
      title: widget.detail.title,
      tmdbId: tmdbId,
      episodeNumber: _currentIndex + 1,
    );
  }

  // ── 投屏到 PC（CineLink）─────────────────────────────────
  //
  // 手机是大脑：把已解析的播放地址 + 防盗链头 + 已匹配的弹幕整包推给 PC，
  // 本地暂停省电，跳遥控页。选集由遥控页回调 _resolveCastEpisode 重新解析。

  CastLoadPayload _castPayloadFor(
    AggregatorPlaySession session,
    int index, {
    int positionSeconds = 0,
  }) {
    return CastLoadPayload(
      url: session.playUrl,
      headers: session.headers,
      title: widget.detail.title,
      cover: widget.detail.bestPoster ?? '',
      episodeLabel:
          index >= 0 && index < _playable.length ? _playable[index].name : '',
      positionSeconds: positionSeconds,
    );
  }

  /// 不动播放器本地状态，单独为投屏拉一包弹幕（切集用）。
  Future<List<Map<String, dynamic>>> _castDanmakuFor(int index) async {
    try {
      final DanmakuSource source = Pref.danmakuSource == 'dandanplay'
          ? DanDanPlayService()
          : LogvarDanmuService();
      if (!source.hasCredentials) return const [];
      final items = await source.fetchDanmaku(
        title: widget.detail.title,
        tmdbId: widget.detail.tmdb?.tmdbId,
        episodeNumber: index + 1,
      );
      return danmakuToWire(items);
    } catch (_) {
      return const [];
    }
  }

  Future<CastEpisodeBundle> _resolveCastEpisode(int index) async {
    final session = await _detailEngine.buildPlaySession(
      widget.detail,
      episodeIndex: index,
    );
    return CastEpisodeBundle(
      payload: _castPayloadFor(session, index),
      danmaku: await _castDanmakuFor(index),
    );
  }

  Future<void> _castToPc() async {
    final session = _session;
    if (session == null) {
      SmartDialog.showToast('还没有可播放的源');
      return;
    }
    try {
      await _ctrl.player.pause();
    } catch (_) {}
    await Get.toNamed(Routes.castRemote, arguments: {
      'payload': _castPayloadFor(
        session,
        _currentIndex,
        positionSeconds: _ctrl.position.value.inSeconds,
      ),
      'danmaku': danmakuToWire(_ctrl.danmakuItems),
      'episodes': _playable.map((e) => e.name).toList(),
      'currentIndex': _currentIndex,
      'resolveEpisode': _resolveCastEpisode,
    });
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
      _updateMediaInfo(session.title);
      await _ctrl.open(url: session.playUrl, headers: session.headers);
      _fetchDanmaku();
    } catch (e) {
      SmartDialog.showToast('播放失败，建议换源');
    }
  }

  Future<void> _handleDebateSeek(int episodeIndex, int? startMs) async {
    if (_playable.isEmpty) {
      SmartDialog.showToast('暂无可播放片段');
      return;
    }
    final targetIndex = episodeIndex.clamp(0, _playable.length - 1);
    if (targetIndex != _currentIndex || _session == null) {
      await _playEpisode(targetIndex);
    }
    if (startMs != null && startMs > 0) {
      await _ctrl.seekTo(Duration(milliseconds: startMs));
      SmartDialog.showToast('已跳转到片段');
    } else {
      _tabCtrl.animateTo(0);
      SmartDialog.showToast('暂无精确时间轴，已切回播放');
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
    _historySaveTimer?.cancel();
    _saveHistory();
    _tabCtrl.dispose();
    _danmakuWorker?.dispose();
    _audioHandler?.detach();
    Get.delete<KazumiPlayerController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fullscreen = _ctrl.isFullscreen.value;
      // 退出全屏后方向旋转是异步的，landscape 期间强制保持全屏布局防溢出
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final showFullLayout = fullscreen || isLandscape;
      return PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && fullscreen) _ctrl.setFullscreen(false);
        },
        child: Scaffold(
          backgroundColor: showFullLayout
              ? Colors.black
              : Theme.of(context).colorScheme.surface,
          body: showFullLayout
              ? _buildPlayer(fullscreen: fullscreen)
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
                              onSeek: _handleDebateSeek,
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
      // 从当前位置续播，而不是回到建会话时的历史位置
      onRetry: _ctrl.retryFromCurrentPosition,
      onOpenInWebView: _openInWebView,
      onCast: () => _castToPc(),
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
  final _biliKey = GlobalKey<BiliVideoSectionState>();
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

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _biliKey.currentState?.loadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
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
        // ── B 站相关视频 ──
        BiliVideoSection(
          key: _biliKey,
          movieTitle: detail.title,
          year: detail.year,
        ),
        ],
      ],
      ),
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
