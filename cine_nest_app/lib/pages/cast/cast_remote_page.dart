import 'dart:async';

import 'package:cine_nest/services/cast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// 投屏遥控页：视频在 PC（CineLink）上播，手机变遥控器。
///
/// 路由参数（Get.arguments）：
///   payload: `CastLoadPayload`          必填，进页即推
///   danmaku: `List<Map>?`               弹幕线上格式，跟在 load 后推
///   episodes: `List<String>?`           集名列表（有则显示选集）
///   currentIndex: `int?`
///   resolveEpisode: `Future<CastEpisodeBundle> Function(int)?`  切集解析闭包
///   room: `String?`                     默认 cinenest
class CastRemotePage extends StatefulWidget {
  const CastRemotePage({super.key});

  @override
  State<CastRemotePage> createState() => _CastRemotePageState();
}

class _CastRemotePageState extends State<CastRemotePage> {
  CastChannel? _channel;
  late String _room;
  late CastLoadPayload _payload;
  List<Map<String, dynamic>> _danmaku = const [];
  List<String> _episodes = const [];
  int _currentIndex = 0;
  Future<CastEpisodeBundle> Function(int index)? _resolveEpisode;

  CastPlaybackState? _state;
  DateTime? _lastStateAt;
  bool _connected = false;
  bool _switching = false;
  bool _danmakuOn = true;
  double _rate = 1.0;
  double? _dragValue;
  Timer? _staleTimer;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : <String, dynamic>{};
    _room = args['room']?.toString() ?? kDefaultCastRoom;
    _payload = args['payload'] is CastLoadPayload
        ? args['payload'] as CastLoadPayload
        : const CastLoadPayload(url: '');
    if (args['danmaku'] is List) {
      _danmaku = List<Map<String, dynamic>>.from(
        (args['danmaku'] as List).whereType<Map>().map(Map<String, dynamic>.from),
      );
    }
    if (args['episodes'] is List) {
      _episodes = List<String>.from(
        (args['episodes'] as List).map((e) => e.toString()),
      );
    }
    _currentIndex = args['currentIndex'] is int ? args['currentIndex'] as int : 0;
    if (args['resolveEpisode'] is Future<CastEpisodeBundle> Function(int)) {
      _resolveEpisode = args['resolveEpisode'] as Future<CastEpisodeBundle> Function(int);
    }
    _connect();
    // 每秒刷一次"PC 失联"判定用的界面
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _channel?.dispose();
    super.dispose();
  }

  void _connect() {
    _channel?.dispose();
    _channel = CastChannel(
      room: _room,
      onState: (state) {
        if (!mounted) return;
        setState(() {
          _state = state;
          _lastStateAt = DateTime.now();
          if (_dragValue == null) _rate = state.rate;
        });
      },
      onError: (message) {
        if (!mounted) return;
        SmartDialog.showToast('PC 播放失败：$message\n可回播放页用屏幕镜像兜底');
      },
      onConnection: (connected) {
        if (mounted) setState(() => _connected = connected);
      },
    );
    _channel!.connect();
    // WS 握手留一拍，再推本次投送内容
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _sendCurrent();
    });
  }

  void _sendCurrent() {
    if (_payload.url.isEmpty) return;
    _channel?.sendLoad(_payload);
    if (_danmaku.isNotEmpty) {
      _channel?.sendDanmaku(_danmaku);
    }
  }

  bool get _pcAlive =>
      _lastStateAt != null &&
      DateTime.now().difference(_lastStateAt!) < const Duration(seconds: 5);

  Future<void> _switchEpisode(int index) async {
    final resolver = _resolveEpisode;
    if (resolver == null || _switching || index == _currentIndex) return;
    setState(() => _switching = true);
    try {
      final bundle = await resolver(index);
      _payload = bundle.payload;
      _danmaku = bundle.danmaku;
      _currentIndex = index;
      _state = null;
      _sendCurrent();
    } catch (_) {
      SmartDialog.showToast('解析该集失败，建议回播放页换源');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _editRoom() async {
    final controller = TextEditingController(text: _room);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('房间号'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            helperText: '需与 CineLink 投屏播放页一致（默认 cinenest）',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || value == _room) return;
    setState(() {
      _room = value;
      _state = null;
      _lastStateAt = null;
    });
    _connect();
  }

  void _stopAndExit() {
    _channel?.stop();
    Get.back();
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '00:00';
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final paused = state?.paused ?? true;
    final duration = state?.duration ?? 0;
    final position = _dragValue ?? state?.position ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投屏遥控'),
        actions: [
          IconButton(
            tooltip: '房间号',
            onPressed: _editRoom,
            icon: const Icon(Icons.meeting_room_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 标题卡
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_payload.cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _payload.cover,
                        width: 56,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 56, height: 80),
                      ),
                    ),
                  if (_payload.cover.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _payload.title.isEmpty ? '投屏中' : _payload.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_payload.episodeLabel.isNotEmpty)
                          Text(
                            _payload.episodeLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _statusChip(
                              theme,
                              _connected ? '信令已连接' : '信令断开',
                              _connected,
                            ),
                            _statusChip(
                              theme,
                              _pcAlive
                                  ? (state?.buffering == true
                                      ? 'PC 缓冲中'
                                      : paused
                                          ? 'PC 已暂停'
                                          : 'PC 播放中')
                                  : '未收到 PC 状态',
                              _pcAlive,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_pcAlive) ...[
            const SizedBox(height: 8),
            Text(
              '确认 PC 端 CineLink 在运行且房间号一致（侧边栏「投屏播放」）',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 16),

          // 进度
          Slider(
            value: duration > 0 ? position.clamp(0, duration) : 0,
            max: duration > 0 ? duration : 1,
            onChanged: duration > 0
                ? (value) => setState(() => _dragValue = value)
                : null,
            onChangeEnd: (value) {
              _channel?.seek(value);
              setState(() => _dragValue = null);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTime(position), style: theme.textTheme.bodySmall),
                Text(_formatTime(duration), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 主控制
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                iconSize: 28,
                onPressed: () =>
                    _channel?.seek((position - 10).clamp(0, double.infinity)),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 20),
              IconButton.filled(
                iconSize: 40,
                onPressed: () =>
                    paused ? _channel?.play() : _channel?.pause(),
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                iconSize: 28,
                onPressed: () => _channel?.seek(position + 10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 倍速 + 弹幕
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [0.5, 1.0, 1.25, 1.5, 2.0].map((rate) {
                    return ChoiceChip(
                      selected: rate == _rate,
                      label: Text('${rate}x'),
                      onSelected: (_) {
                        setState(() => _rate = rate);
                        _channel?.setRate(rate);
                      },
                    );
                  }).toList(),
                ),
              ),
              FilterChip(
                selected: _danmakuOn,
                label: const Text('弹幕'),
                avatar: _danmakuOn ? null : const Icon(Icons.comments_disabled),
                onSelected: _danmaku.isEmpty
                    ? null
                    : (value) {
                        setState(() => _danmakuOn = value);
                        _channel?.toggleDanmaku(value);
                      },
              ),
            ],
          ),

          // 选集
          if (_episodes.isNotEmpty && _resolveEpisode != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text('选集', style: theme.textTheme.titleMedium),
                if (_switching) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _episodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ChoiceChip(
                  selected: index == _currentIndex,
                  label: Text(_episodes[index]),
                  onSelected:
                      _switching ? null : (_) => _switchEpisode(index),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sendCurrent,
                  icon: const Icon(Icons.cast_rounded),
                  label: const Text('重新投送'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _stopAndExit,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('结束投屏'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ThemeData theme, String text, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ok
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ok
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
