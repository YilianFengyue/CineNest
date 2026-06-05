import 'dart:async';

import 'package:cine_nest/models/video_source.dart';
import 'package:cine_nest/pages/player/services/source_api_service.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _title = 'CineNest Player';
  String _message = 'Searching sources...';
  String? _error;
  String? _url;
  bool _loadingSources = true;
  bool _switching = false;
  bool _fullscreen = false;
  bool _showVideoControls = false;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _switching = false;
        _message = 'Playback failed. Choose another source or retry.';
      });
    });
    _readArgs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSources();
      }
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
    _restoreOrientation();
    super.dispose();
  }

  void _readArgs() {
    final args = Get.arguments;
    final title = args is Map ? args['title']?.toString() : null;
    _movieName = title == null || title.trim().isEmpty
        ? _movieName
        : title.trim();
    _title = _movieName;
  }

  Future<void> _loadSources() async {
    setState(() {
      _loadingSources = true;
      _switching = true;
      _error = null;
      _message = 'Searching sources for $_movieName...';
      _sources = const [];
      _selectedSource = null;
      _parsedSource = null;
      _selectedEpisodeIndex = 0;
    });

    var warning = '';
    var sources = <VideoSource>[];
    try {
      sources = await _api.searchSources(_movieName);
    } catch (e) {
      warning = 'Source search failed, using fallback. ';
      sources = _api.fallbackSources(_movieName);
    }

    try {
      final bili = await _api.searchBilibili('$_movieName 解说');
      sources = _mergeSources([...sources, ...bili]);
    } catch (e) {
      warning = '${warning}Bilibili search failed. ';
      sources = _mergeSources([
        ...sources,
        _api.fallbackBilibili('$_movieName 解说'),
      ]);
    }

    sources = _sortSources(sources);
    if (!mounted) {
      return;
    }
    setState(() {
      _sources = sources;
      _loadingSources = false;
      _message = sources.isEmpty
          ? '${warning}No source found.'
          : '${warning}Found ${sources.length} source(s). Preparing default source...';
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
      if (source.id.trim().isEmpty) {
        continue;
      }
      if (seen.add(source.id)) {
        merged.add(source);
      }
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
    if (source.type == SourceType.web) {
      return 2;
    }
    return 3;
  }

  Future<void> _autoPlayDefault(List<VideoSource> sources) async {
    final directCandidates = sources
        .where((source) => source.type != SourceType.bilibili)
        .toList();
    for (final source in directCandidates) {
      final ok = await _switchSource(source, autoAdvance: true);
      if (ok) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _switching = false;
      _message =
          'No direct video source worked. Choose Bilibili/WebView below.';
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
      _message = 'Preparing ${source.name}...';
    });

    try {
      final parsed = await _parseForPlayback(source, episodeIndex);
      final playUrl = parsed.playUrl;
      if (playUrl == null || playUrl.isEmpty) {
        throw Exception('This source has no play URL.');
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
          _message = 'Open this source with WebView.';
        });
        return false;
      }

      _parsedSource = parsed;
      _url = playUrl;
      _title = parsed.name.isEmpty ? source.name : parsed.name;
      await _player.open(Media(playUrl));
      await _player.setRate(_rate);
      if (!mounted) {
        return true;
      }
      setState(() {
        _switching = false;
        _message = _episodeLabel(parsed, episodeIndex);
      });
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _switching = false;
        _error = e.toString();
        _message = autoAdvance
            ? 'Default source failed, trying next source...'
            : 'Source failed. Choose another source or retry.';
      });
      return false;
    }
  }

  Future<VideoSource> _parseForPlayback(
    VideoSource source,
    int episodeIndex,
  ) async {
    if (source.playUrl != null && source.playUrl!.isNotEmpty) {
      return source;
    }
    return _api.parseSource(source.id, episodeIndex: episodeIndex);
  }

  String _episodeLabel(VideoSource source, int episodeIndex) {
    if (source.episodes.length <= 1) {
      return 'Playing';
    }
    final episode = source.episodes.firstWhere(
      (item) => item.index == episodeIndex,
      orElse: () => source.episodes.first,
    );
    return 'Playing ${episode.title}';
  }

  bool _isDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('/upgcxcode/');
  }

  Future<void> _toggleFullscreen() async {
    if (_fullscreen) {
      await _exitFullscreen();
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) {
      setState(() => _fullscreen = true);
    }
  }

  Future<void> _exitFullscreen() async {
    await _restoreOrientation();
    if (mounted && _fullscreen) {
      setState(() => _fullscreen = false);
    }
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _setRate(double value) async {
    await _player.setRate(value);
    if (mounted) {
      setState(() => _rate = value);
    }
  }

  void _openWebView() {
    final url = _url;
    if (url == null || url.isEmpty) {
      return;
    }
    Get.toNamed(Routes.webviewPlayer, arguments: {'url': url, 'title': _title});
  }

  @override
  Widget build(BuildContext context) {
    final video = _VideoFrame(
      controller: _videoController,
      loading: _switching,
      error: _error,
      showControls: _showVideoControls,
      player: _player,
      onTap: () => setState(() => _showVideoControls = !_showVideoControls),
      onFullscreen: _toggleFullscreen,
      onRetry: _selectedSource == null
          ? _loadSources
          : () => _switchSource(
              _selectedSource!,
              episodeIndex: _selectedEpisodeIndex,
            ),
      onWebView: _url == null ? null : _openWebView,
    );

    if (_fullscreen) {
      return WillPopScope(
        onWillPop: () async {
          await _exitFullscreen();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: AspectRatio(aspectRatio: 16 / 9, child: video),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Exit fullscreen',
                      onPressed: _exitFullscreen,
                      icon: const Icon(
                        Icons.fullscreen_exit,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: _SpeedButton(
                    rate: _rate,
                    onRateChanged: _setRate,
                    dark: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_movieName),
        actions: [
          IconButton(
            tooltip: 'Refresh sources',
            onPressed: _loadingSources ? null : _loadSources,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: video),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(_message),
                  const SizedBox(height: 12),
                  _ProgressBar(player: _player),
                  const SizedBox(height: 12),
                  _Controls(
                    player: _player,
                    rate: _rate,
                    onRateChanged: _setRate,
                    onFullscreen: _toggleFullscreen,
                    onWebView: _url == null ? null : _openWebView,
                    onRetry: _selectedSource == null
                        ? _loadSources
                        : () => _switchSource(
                            _selectedSource!,
                            episodeIndex: _selectedEpisodeIndex,
                          ),
                  ),
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
                    'Sources',
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

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({
    required this.controller,
    required this.loading,
    required this.error,
    required this.showControls,
    required this.player,
    required this.onTap,
    required this.onFullscreen,
    required this.onRetry,
    this.onWebView,
  });

  final VideoController controller;
  final bool loading;
  final String? error;
  final bool showControls;
  final Player player;
  final VoidCallback onTap;
  final VoidCallback onFullscreen;
  final VoidCallback onRetry;
  final VoidCallback? onWebView;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Video(controller: controller, controls: null),
          ),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (showControls && error == null && !loading)
            _VideoTapControls(player: player, onFullscreen: onFullscreen),
          if (error != null)
            _ErrorOverlay(
              error: error!,
              onRetry: onRetry,
              onWebView: onWebView,
            ),
        ],
      ),
    );
  }
}

class _VideoTapControls extends StatelessWidget {
  const _VideoTapControls({required this.player, required this.onFullscreen});

  final Player player;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withAlpha(90)),
      child: Stack(
        children: [
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              initialData: player.state.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 48,
                    color: Colors.white,
                    onPressed: playing ? player.pause : player.play,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                color: Colors.white,
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.player,
    required this.rate,
    required this.onRateChanged,
    required this.onFullscreen,
    required this.onRetry,
    this.onWebView,
  });

  final Player player;
  final double rate;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onFullscreen;
  final VoidCallback onRetry;
  final VoidCallback? onWebView;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return FilledButton.tonalIcon(
              onPressed: playing ? player.pause : player.play,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              label: Text(playing ? 'Pause' : 'Play'),
            );
          },
        ),
        _SpeedButton(rate: rate, onRateChanged: onRateChanged),
        OutlinedButton.icon(
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen),
          label: const Text('Fullscreen'),
        ),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        OutlinedButton.icon(
          onPressed: onWebView,
          icon: const Icon(Icons.public),
          label: const Text('WebView'),
        ),
      ],
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.rate,
    required this.onRateChanged,
    this.dark = false,
  });

  final double rate;
  final ValueChanged<double> onRateChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final child = PopupMenuButton<double>(
      initialValue: rate,
      onSelected: onRateChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 0.5, child: Text('0.5x')),
        PopupMenuItem(value: 1.0, child: Text('1.0x')),
        PopupMenuItem(value: 1.25, child: Text('1.25x')),
        PopupMenuItem(value: 1.5, child: Text('1.5x')),
        PopupMenuItem(value: 2.0, child: Text('2.0x')),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? Colors.black54 : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: dark
                ? Colors.white70
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speed,
                size: 18,
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${rate}x',
                style: TextStyle(
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!dark) {
      return child;
    }
    return Material(color: Colors.transparent, child: child);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.stream.position,
          initialData: player.state.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final max = duration.inMilliseconds <= 0
                ? 1.0
                : duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .clamp(0, max.toInt())
                .toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: value,
                  max: max,
                  onChanged: (next) {
                    player.seek(Duration(milliseconds: next.round()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    StreamBuilder<bool>(
                      stream: player.stream.buffering,
                      initialData: player.state.buffering,
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data == true ? 'Buffering' : 'Ready',
                        );
                      },
                    ),
                    Text(_formatDuration(duration)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
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
    if (episodes.length <= 1) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
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
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(
                    '\u7b2c${index + 1}\u96c6',
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
    if (sources.isEmpty) {
      return const Text('No sources yet.');
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final label = [
      source.type.name,
      if (source.quality != null && source.quality!.isNotEmpty) source.quality!,
      if (source.type == SourceType.bilibili) 'WebView',
    ].join(' / ');

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withAlpha(120)
              : colorScheme.surface,
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
                        ? Icons.ondemand_video
                        : Icons.play_circle_outline,
                    size: 18,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
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
                label,
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

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.error,
    required this.onRetry,
    this.onWebView,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback? onWebView;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withAlpha(210)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 42),
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                  OutlinedButton(
                    onPressed: onWebView,
                    child: const Text('Open WebView'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
