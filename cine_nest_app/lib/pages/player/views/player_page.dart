import 'dart:async';

import 'package:cine_nest/pages/player/services/source_api_service.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _api = const SourceApiService();
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<String>? _errorSubscription;
  String _title = 'CineNest Player';
  String? _url;
  String? _sourceId;
  String _message = 'Preparing player...';
  String? _error;
  bool _loading = true;
  bool _fullscreen = false;
  double _rate = 1.0;

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
        _loading = false;
        _message = 'Playback failed. Retry or use WebView.';
      });
    });
    _readRouteParams();
    _load();
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
    _restoreOrientation();
    super.dispose();
  }

  void _readRouteParams() {
    final arguments = Get.arguments;
    if (arguments is Map) {
      _title = _stringArg(arguments['title']) ?? _title;
      _url = _stringArg(arguments['url']);
      _sourceId = _stringArg(arguments['source_id']);
      return;
    }

    final params = Get.parameters;
    _title = _safeDecode(params['title']) ?? _title;
    _url = _emptyToNull(params['url']);
    _sourceId = _emptyToNull(params['source_id']);
  }

  String? _stringArg(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return _safeDecode(value.trim());
  }

  String? _safeDecode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      return Uri.decodeComponent(value.trim());
    } catch (_) {
      return value.trim();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = 'Loading $_title...';
    });

    try {
      var playUrl = _url;
      if ((playUrl == null || playUrl.isEmpty) && _sourceId != null) {
        final source = await _api.parseSource(_sourceId!);
        playUrl = source.playUrl;
        _title = source.name.isEmpty ? _title : source.name;
      }

      if (playUrl == null || playUrl.isEmpty) {
        throw Exception('No playable URL returned.');
      }

      if (!_isDirectVideo(playUrl)) {
        Get.offNamed(
          Routes.webviewPlayer,
          arguments: {'url': playUrl, 'title': _title},
        );
        return;
      }

      _url = playUrl;
      await _player.open(Media(playUrl));
      await _player.setRate(_rate);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _message = 'Playing';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
        _message = 'Failed to prepare playback.';
      });
    }
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
    final theme = Theme.of(context);
    final video = DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _videoController),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            _ErrorOverlay(
              error: _error!,
              onRetry: _load,
              onWebView: _url == null ? null : _openWebView,
            ),
        ],
      ),
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
            ],
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: video),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(_message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              _ProgressBar(player: _player),
              const SizedBox(height: 12),
              _Controls(
                player: _player,
                rate: _rate,
                onRateChanged: _setRate,
                onFullscreen: _toggleFullscreen,
                onWebView: _url == null ? null : _openWebView,
                onRetry: _load,
              ),
              if (_url != null) ...[
                const SizedBox(height: 16),
                Text('Play URL', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(_url!),
              ],
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: SingleChildScrollView(child: content),
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
        PopupMenuButton<double>(
          initialValue: rate,
          onSelected: onRateChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0.5, child: Text('0.5x')),
            PopupMenuItem(value: 1.0, child: Text('1.0x')),
            PopupMenuItem(value: 1.25, child: Text('1.25x')),
            PopupMenuItem(value: 1.5, child: Text('1.5x')),
            PopupMenuItem(value: 2.0, child: Text('2.0x')),
          ],
          child: ActionChip(
            avatar: const Icon(Icons.speed),
            label: Text('${rate}x'),
            onPressed: null,
          ),
        ),
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
