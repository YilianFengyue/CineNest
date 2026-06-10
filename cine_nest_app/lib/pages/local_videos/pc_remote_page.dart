import 'dart:async';
import 'dart:convert';

import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/local_video.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PcRemotePage extends StatefulWidget {
  const PcRemotePage({super.key});

  @override
  State<PcRemotePage> createState() => _PcRemotePageState();
}

class _PcRemotePageState extends State<PcRemotePage> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  late final String _room;
  late final String _url;
  late final LocalVideo? _video;
  late final Player _player;
  late final VideoController _videoController;
  String _status = 'Connecting...';
  String _pcState = 'Waiting for PC player';
  String _phoneState = 'Waiting for local preview';
  double _rate = 1.0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : <String, dynamic>{};
    _room = args['room']?.toString() ?? 'cinenest';
    _url = args['url']?.toString() ?? '';
    final rawVideo = args['video'];
    _video = rawVideo is Map
        ? LocalVideo.fromJson(Map<String, dynamic>.from(rawVideo))
        : null;
    _player = Player();
    _videoController = VideoController(_player);
    _connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _player.dispose();
    super.dispose();
  }

  String get _pcPlayerUrl {
    final base = Request.dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base/pc-player?room=${Uri.encodeComponent(_room)}';
  }

  Uri get _wsUri {
    final base = Uri.parse(Request.dio.options.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final port = base.hasPort ? ':${base.port}' : '';
    return Uri.parse(
      '$scheme://${base.host}$port/ws/pc-control/${Uri.encodeComponent(_room)}',
    );
  }

  void _connect() {
    try {
      final channel = WebSocketChannel.connect(_wsUri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (error) => setState(() => _status = 'Error: $error'),
        onDone: () => setState(() => _status = 'Disconnected'),
      );
      setState(() => _status = 'Connected');
      if (_url.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _sendLoad(autoplay: true);
        });
      }
    } catch (e) {
      setState(() => _status = 'Connect failed: $e');
    }
  }

  void _onMessage(dynamic event) {
    try {
      final data = jsonDecode(event.toString());
      if (data is Map && data['type'] == 'state') {
        final pos = (data['position'] as num?)?.toDouble() ?? 0;
        final dur = (data['duration'] as num?)?.toDouble() ?? 0;
        final paused = data['paused'] == true;
        setState(() {
          _pcState =
              '${paused ? 'Paused' : 'Playing'} · ${_formatTime(pos)} / ${_formatTime(dur)}';
        });
      }
    } catch (_) {
      // Ignore non-json diagnostic messages.
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode({'sender': 'phone', ...message}));
  }

  Future<void> _sendLoad({bool autoplay = true}) async {
    _send({
      'type': 'load',
      'url': _url,
      'title': _video?.title ?? 'PC local video',
      'autoplay': autoplay,
    });
    await _loadPhonePreview(autoplay: autoplay);
  }

  Future<void> _loadPhonePreview({bool autoplay = true}) async {
    if (_url.isEmpty) return;
    setState(() => _phoneState = 'Loading phone preview...');
    try {
      await _player.open(Media(_url));
      await _player.setRate(_rate);
      if (!autoplay) {
        await _player.pause();
      }
      if (mounted) {
        setState(() => _phoneState = autoplay ? 'Phone preview playing' : 'Phone preview ready');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phoneState = 'Phone preview failed: $e');
      }
    }
  }

  Future<void> _playBoth() async {
    _send({'type': 'play'});
    await _player.play();
    if (mounted) setState(() => _phoneState = 'Phone preview playing');
  }

  Future<void> _pauseBoth() async {
    _send({'type': 'pause'});
    await _player.pause();
    if (mounted) setState(() => _phoneState = 'Phone preview paused');
  }

  Future<void> _seekBy(int seconds) async {
    final current = _player.state.position.inSeconds;
    final target = (current + seconds).clamp(0, 999999);
    _send({'type': 'seek', 'position': target});
    await _player.seek(Duration(seconds: target));
  }

  Future<void> _setRate(double rate) async {
    setState(() => _rate = rate);
    _send({'type': 'setRate', 'rate': rate});
    await _player.setRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PC remote control')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: _url.isEmpty
                    ? const Center(
                        child: Text(
                          'No local preview',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : Video(controller: _videoController),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room: $_room', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText('PC page: $_pcPlayerUrl'),
                  const SizedBox(height: 8),
                  Text('WebSocket: $_status'),
                  Text('PC state: $_pcState'),
                  Text('Phone state: $_phoneState'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(_video?.title ?? 'No video selected', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _url.isEmpty ? null : () => _sendLoad(),
                icon: const Icon(Icons.cast_rounded),
                label: const Text('Load to PC'),
              ),
              FilledButton.icon(
                onPressed: _playBoth,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
              OutlinedButton.icon(
                onPressed: _pauseBoth,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause'),
              ),
              OutlinedButton.icon(
                onPressed: () => _seekBy(-10),
                icon: const Icon(Icons.replay_10_rounded),
                label: const Text('-10s'),
              ),
              OutlinedButton.icon(
                onPressed: () => _seekBy(10),
                icon: const Icon(Icons.forward_10_rounded),
                label: const Text('+10s'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Speed', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1.0, 1.25, 1.5, 2.0].map((rate) {
              final selected = rate == _rate;
              return ChoiceChip(
                selected: selected,
                label: Text('${rate}x'),
                onSelected: (_) => _setRate(rate),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '00:00';
    final total = seconds.round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
