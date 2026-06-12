import 'dart:async';
import 'dart:convert';

import 'package:cine_nest/http/init.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dandanplay_service.dart';

/// 投屏链路（协议 v2，跑在后端 /ws/pc-control/{room} 房间广播上）。
///
/// 手机是大脑：搜源/解析/弹幕匹配全在手机，这里只把成品推给 PC——
/// `load_remote`（最终播放地址 + 防盗链头）和 `danmaku`（已匹配好的列表）。
/// PC 端（CineLink 投屏播放页）负责渲染，事件驱动回报 `state`。
const String kDefaultCastRoom = 'cinenest';

/// 一次投送的全部内容（防盗链 headers 必须原样带上，PC 主进程注入）。
class CastLoadPayload {
  const CastLoadPayload({
    required this.url,
    this.headers = const {},
    this.title = '',
    this.cover = '',
    this.episodeLabel = '',
    this.positionSeconds = 0,
  });

  final String url;
  final Map<String, String> headers;
  final String title;
  final String cover;
  final String episodeLabel;
  final int positionSeconds;

  Map<String, dynamic> toMessage() => {
        'type': 'load_remote',
        'url': url,
        'headers': headers,
        'title': title,
        'cover': cover,
        'episodeLabel': episodeLabel,
        'position': positionSeconds,
      };
}

/// PC 回报的播放状态。
class CastPlaybackState {
  const CastPlaybackState({
    required this.position,
    required this.duration,
    required this.paused,
    required this.rate,
    required this.buffering,
  });

  final double position;
  final double duration;
  final bool paused;
  final double rate;
  final bool buffering;

  static CastPlaybackState? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'state') return null;
    return CastPlaybackState(
      position: (data['position'] as num?)?.toDouble() ?? 0,
      duration: (data['duration'] as num?)?.toDouble() ?? 0,
      paused: data['paused'] == true,
      rate: (data['rate'] as num?)?.toDouble() ?? 1.0,
      buffering: data['buffering'] == true,
    );
  }
}

/// 切集时由播放页闭包解析出的新一包内容。
class CastEpisodeBundle {
  const CastEpisodeBundle({required this.payload, this.danmaku = const []});

  final CastLoadPayload payload;
  final List<Map<String, dynamic>> danmaku;
}

/// DanDanComment（timeMs/mode/color/content）→ 线上格式 {t秒, text, color, mode}。
List<Map<String, dynamic>> danmakuToWire(List<DanDanComment> items) {
  String modeName(int mode) => switch (mode) {
        5 => 'top',
        4 => 'bottom',
        _ => 'scroll',
      };
  return [
    for (final item in items)
      {
        't': item.timeMs / 1000,
        'text': item.content,
        'color':
            '#${(item.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'mode': modeName(item.mode),
      },
  ];
}

/// 房间 WS 通道：连接、收 PC 状态、发控制指令。生命周期归遥控页所有。
class CastChannel {
  CastChannel({
    this.room = kDefaultCastRoom,
    this.onState,
    this.onError,
    this.onConnection,
  });

  final String room;
  final void Function(CastPlaybackState state)? onState;

  /// PC 端播放失败（编码/防盗链顶不住），提示用户走屏幕镜像兜底
  final void Function(String message)? onError;
  final void Function(bool connected)? onConnection;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Uri get _wsUri {
    final base = Uri.parse(Request.dio.options.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final port = base.hasPort ? ':${base.port}' : '';
    return Uri.parse(
      '$scheme://${base.host}$port/ws/pc-control/${Uri.encodeComponent(room)}',
    );
  }

  void connect() {
    if (_channel != null) return;
    final channel = WebSocketChannel.connect(_wsUri);
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) => onConnection?.call(false),
      onDone: () => onConnection?.call(false),
    );
    onConnection?.call(true);
    send({'type': 'hello'});
  }

  void _onMessage(dynamic event) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(event.toString());
      if (decoded is! Map) return;
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    if (data['sender'] == 'phone') return; // 房间广播，过滤自己的回环

    final state = CastPlaybackState.tryParse(data);
    if (state != null) {
      onState?.call(state);
      return;
    }
    if (data['type'] == 'error') {
      onError?.call(data['message']?.toString() ?? 'PC 播放失败');
    }
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode({'sender': 'phone', ...message}));
  }

  void sendLoad(CastLoadPayload payload) => send(payload.toMessage());

  void sendDanmaku(List<Map<String, dynamic>> items) =>
      send({'type': 'danmaku', 'items': items});

  void play() => send({'type': 'play'});

  void pause() => send({'type': 'pause'});

  void seek(double seconds) => send({'type': 'seek', 'position': seconds});

  void setRate(double rate) => send({'type': 'setRate', 'rate': rate});

  void toggleDanmaku(bool visible) =>
      send({'type': 'danmakuToggle', 'visible': visible});

  /// 结束投屏：PC 清空播放器回到等待页
  void stop() => send({'type': 'stop'});

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
