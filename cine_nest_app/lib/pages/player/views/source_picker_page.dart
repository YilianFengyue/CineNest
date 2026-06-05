import 'dart:async';

import 'package:cine_nest/models/video_source.dart';
import 'package:cine_nest/pages/player/services/source_api_service.dart';
import 'package:cine_nest/pages/player/widgets/player_chrome.dart';
import 'package:cine_nest/pages/player/widgets/player_theme.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class SourcePickerPage extends StatefulWidget {
  const SourcePickerPage({super.key});

  @override
  State<SourcePickerPage> createState() => _SourcePickerPageState();
}

class _SourcePickerPageState extends State<SourcePickerPage> {
  final _api = const SourceApiService();
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<String>? _errorSubscription;

  String _movieName = 'The Shawshank Redemption';
  String _title = '播放器';
  String _statusMessage = '正在搜索播放源…';
  String? _error;
  String? _url;
  bool _loadingSources = true;
  bool _switching = false;
  double _rate = 1.0;

  List<VideoSource> _sources = const [];
  VideoSource? _selectedSource;
  VideoSource? _parsedSource;
  int _selectedEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _errorSubscription = _player.stream.error.listen((error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _switching = false;
        _statusMessage = '播放失败，可换源或重试';
      });
    });
    _readArgs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSources();
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _readArgs() {
    final args = Get.arguments;
    final title = args is Map ? args['title']?.toString() : null;
    if (title != null && title.trim().isNotEmpty) {
      _movieName = title.trim();
    }
    _title = _movieName;
  }

  Future<void> _loadSources() async {
    setState(() {
      _loadingSources = true;
      _switching = true;
      _error = null;
      _statusMessage = '正在搜索「$_movieName」的播放源…';
      _sources = const [];
      _selectedSource = null;
      _parsedSource = null;
      _selectedEpisodeIndex = 0;
    });

    var warning = '';
    var sources = <VideoSource>[];
    try {
      sources = await _api.searchSources(_movieName);
    } catch (_) {
      warning = '影视站搜索失败，已降级为内置源。';
      sources = _api.fallbackSources(_movieName);
    }

    try {
      final bili = await _api.searchBilibili('$_movieName 解说');
      sources = _mergeSources([...sources, ...bili]);
    } catch (_) {
      warning = '${warning}Bilibili 搜索失败。';
      sources = _mergeSources([
        ...sources,
        _api.fallbackBilibili('$_movieName 解说'),
      ]);
    }

    sources = _sortSources(sources);
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loadingSources = false;
      _statusMessage = sources.isEmpty
          ? '$warning未找到播放源'
          : '$warning找到 ${sources.length} 个源，正在尝试默认源…';
    });

    if (sources.isNotEmpty) {
      await _autoPlayDefault(sources);
    } else if (mounted) {
      setState(() => _switching = false);
    }
  }

  List<VideoSource> _mergeSources(List<VideoSource> sources) {
    final merged = <VideoSource>[];
    final seen = <String>{};
    for (final source in sources) {
      if (source.id.trim().isEmpty) continue;
      if (seen.add(source.id)) merged.add(source);
    }
    return merged;
  }

  List<VideoSource> _sortSources(List<VideoSource> sources) {
    final sorted = [...sources];
    sorted.sort((a, b) => _sourcePriority(a).compareTo(_sourcePriority(b)));
    return sorted;
  }

  int _sourcePriority(VideoSource source) {
    if (source.type == SourceType.web && !source.id.startsWith('demo:')) {
      return 0;
    }
    if (source.id.startsWith('demo:') || source.type == SourceType.netdisk) {
      return 1;
    }
    if (source.type == SourceType.web) return 2;
    return 3;
  }

  Future<void> _autoPlayDefault(List<VideoSource> sources) async {
    final directCandidates = sources
        .where((source) => source.type != SourceType.bilibili)
        .toList();
    for (final source in directCandidates) {
      final ok = await _switchSource(source, autoAdvance: true);
      if (ok) return;
    }
    if (!mounted) return;
    setState(() {
      _switching = false;
      _statusMessage = '直连源全部失败，请在下方手动选择 Bilibili / 浏览器源';
    });
  }

  Future<bool> _switchSource(
    VideoSource source, {
    int episodeIndex = 0,
    bool autoAdvance = false,
  }) async {
    setState(() {
      _switching = true;
      _error = null;
      _selectedSource = source;
      _selectedEpisodeIndex = episodeIndex;
      _statusMessage = '正在准备「${source.name}」…';
    });

    try {
      final parsed = await _parseForPlayback(source, episodeIndex);
      final playUrl = parsed.playUrl;
      if (playUrl == null || playUrl.isEmpty) {
        throw Exception('该源没有可播放地址');
      }

      if (!_isDirectVideo(playUrl)) {
        if (!autoAdvance) {
          Get.toNamed(
            Routes.webviewPlayer,
            arguments: {'url': playUrl, 'title': parsed.name},
          );
        }
        setState(() {
          _parsedSource = parsed;
          _url = playUrl;
          _switching = false;
          _statusMessage = '该源需通过浏览器播放';
        });
        return false;
      }

      _parsedSource = parsed;
      _url = playUrl;
      _title = parsed.name.isEmpty ? source.name : parsed.name;
      await _player.open(Media(playUrl));
      await _player.setRate(_rate);
      if (!mounted) return true;
      setState(() {
        _switching = false;
        _error = null; // 清掉换源前残留的错误，防止"已成功但仍显示失败"
        _statusMessage = _episodeLabel(parsed, episodeIndex);
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _switching = false;
        _error = e.toString();
        _statusMessage = autoAdvance ? '默认源失败，尝试下一个…' : '该源失败，可换源或重试';
      });
      return false;
    }
  }

  Future<VideoSource> _parseForPlayback(
    VideoSource source,
    int episodeIndex,
  ) async {
    if (source.playUrl != null && source.playUrl!.isNotEmpty) return source;
    return _api.parseSource(source.id, episodeIndex: episodeIndex);
  }

  String _episodeLabel(VideoSource source, int episodeIndex) {
    if (source.episodes.length <= 1) return '正在播放';
    final ep = source.episodes.firstWhere(
      (item) => item.index == episodeIndex,
      orElse: () => source.episodes.first,
    );
    return '正在播放 ${ep.title.isEmpty ? '第${episodeIndex + 1}集' : ep.title}';
  }

  bool _isDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('/upgcxcode/');
  }

  Future<void> _setRate(double value) async {
    await _player.setRate(value);
    if (mounted) setState(() => _rate = value);
  }

  void _openWebView() {
    final url = _url;
    if (url == null || url.isEmpty) return;
    Get.toNamed(Routes.webviewPlayer, arguments: {'url': url, 'title': _title});
  }

  PlayerActions _buildActions(BuildContext context) {
    final episodes = _parsedSource?.episodes ?? const <VideoEpisode>[];
    final episodeBadge = episodes.length > 1
        ? '第 ${_selectedEpisodeIndex + 1} / ${episodes.length} 集'
        : null;
    return PlayerActions(
      title: _title,
      episodeLabel: episodeBadge,
      rate: _rate,
      sources: _sources,
      currentSourceId: _selectedSource?.id,
      episodes: episodes,
      currentEpisodeIndex: _selectedEpisodeIndex,
      switching: _switching,
      onBack: () => Navigator.of(context).maybePop(),
      onPickSource: (src) => _switchSource(src),
      onPickEpisode: (ep) {
        final src = _selectedSource;
        if (src != null) _switchSource(src, episodeIndex: ep.index);
      },
      onChangeRate: _setRate,
      onOpenWebView: _url == null ? null : _openWebView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_movieName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '刷新源',
            onPressed: _loadingSources ? null : _loadSources,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _url == null
                    ? _PlaceholderArea(
                        loading: _switching,
                        message: _statusMessage,
                        error: _error,
                        onRetry: _selectedSource == null
                            ? _loadSources
                            : () => _switchSource(
                                  _selectedSource!,
                                  episodeIndex: _selectedEpisodeIndex,
                                ),
                      )
                    : MaterialVideoControlsTheme(
                        normal: buildPlayerTheme(
                          context: context,
                          fullscreen: false,
                          actions: actions,
                        ),
                        fullscreen: buildPlayerTheme(
                          context: context,
                          fullscreen: true,
                          actions: actions,
                        ),
                        child: Video(
                          controller: _videoController,
                          controls: MaterialVideoControls,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _error != null
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                  ),
                  if (_url != null && _error != null) ...[
                    const SizedBox(height: 8),
                    _ErrorCard(
                      message: _error!,
                      onRetry: _selectedSource == null
                          ? _loadSources
                          : () => _switchSource(
                                _selectedSource!,
                                episodeIndex: _selectedEpisodeIndex,
                              ),
                      onOpenWebView: _url == null ? null : _openWebView,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _EpisodeGrid(
                    source: _parsedSource,
                    selectedEpisodeIndex: _selectedEpisodeIndex,
                    switching: _switching,
                    onEpisodeSelected: (episode) {
                      final source = _selectedSource;
                      if (source != null) {
                        _switchSource(source, episodeIndex: episode.index);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '播放源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _SourceGrid(
                    sources: _sources,
                    selectedSourceId: _selectedSource?.id,
                    loading: _loadingSources || _switching,
                    onSelected: _switchSource,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderArea extends StatelessWidget {
  const _PlaceholderArea({
    required this.loading,
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String message;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.primary,
                  backgroundColor: Colors.white24,
                ),
              )
            else
              Icon(
                error != null
                    ? Icons.error_outline_rounded
                    : Icons.play_circle_outline_rounded,
                color: error != null ? cs.error : Colors.white70,
                size: 40,
              ),
            const SizedBox(height: 12),
            Text(
              error ?? message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
            if (!loading && error != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.onOpenWebView,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenWebView;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
          if (onOpenWebView != null)
            TextButton(
              onPressed: onOpenWebView,
              child: const Text('浏览器播放'),
            ),
        ],
      ),
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  const _EpisodeGrid({
    required this.source,
    required this.selectedEpisodeIndex,
    required this.switching,
    required this.onEpisodeSelected,
  });

  final VideoSource? source;
  final int selectedEpisodeIndex;
  final bool switching;
  final ValueChanged<VideoEpisode> onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    final episodes = source?.episodes ?? const <VideoEpisode>[];
    if (episodes.length <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选集', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth > 600 ? 8 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: episodes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
              ),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final selected = index == selectedEpisodeIndex;
                return FilledButton.tonal(
                  onPressed: switching
                      ? null
                      : () => onEpisodeSelected(
                            VideoEpisode(
                              index: index,
                              title: episode.title,
                              playUrl: episode.playUrl,
                            ),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                  ),
                  child: Text(
                    '第${index + 1}集',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({
    required this.sources,
    required this.selectedSourceId,
    required this.loading,
    required this.onSelected,
  });

  final List<VideoSource> sources;
  final String? selectedSourceId;
  final bool loading;
  final ValueChanged<VideoSource> onSelected;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const Text('暂无播放源');
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sources.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) {
            final source = sources[index];
            final selected = source.id == selectedSourceId;
            return _SourceTile(
              source: source,
              selected: selected,
              disabled: loading,
              onTap: () => onSelected(source),
            );
          },
        );
      },
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final VideoSource source;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = selected ? cs.primary : cs.outlineVariant;
    final tags = <String>[
      switch (source.type) {
        SourceType.bilibili => 'Bilibili',
        SourceType.netdisk => '网盘',
        SourceType.web => '影视站',
      },
      if (source.quality != null && source.quality!.isNotEmpty) source.quality!,
      if (source.type == SourceType.bilibili) '浏览器',
    ];

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    source.type == SourceType.bilibili
                        ? Icons.ondemand_video_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 18,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      source.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tags.join(' / '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
