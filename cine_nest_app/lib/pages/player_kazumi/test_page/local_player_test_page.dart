import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';
import '../services/kazumi_audio_handler.dart';
import '../services/pip_service.dart';
import '../services/screenshot_service.dart';
import '../widgets/kazumi_player_view.dart';

/// 本地视频 / 在线 m3u8 播放测试页（从设置入口进入）。
///
/// 提供：
/// - 几条公开 m3u8 / mp4 测试链
/// - 粘贴自定义 URL
/// - 选择本地视频文件
/// - 点击进 KazumiPlayerView 播放
class LocalPlayerTestPage extends StatefulWidget {
  const LocalPlayerTestPage({super.key});

  @override
  State<LocalPlayerTestPage> createState() => _LocalPlayerTestPageState();
}

class _LocalPlayerTestPageState extends State<LocalPlayerTestPage> {
  final _urlCtrl = TextEditingController();

  static const _presets = <_Preset>[
    _Preset(
      label: 'Apple HLS Basic (m3u8)',
      url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
    ),
    _Preset(
      label: 'Big Buck Bunny (mp4)',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    _Preset(
      label: 'Sintel (m3u8)',
      url:
          'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
    ),
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path != null && mounted) {
        _open(path, title: result!.files.single.name);
      }
    } catch (e) {
      SmartDialog.showToast('文件选择失败：$e');
    }
  }

  void _openFromInput() {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      SmartDialog.showToast('请先填入视频地址');
      return;
    }
    _open(raw, title: '自定义播放');
  }

  void _open(String url, {required String title}) {
    Get.to(() => _PlayerHost(url: url, title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放器测试 · Kazumi 风')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'm3u8 / mp4 URL',
              border: OutlineInputBorder(),
              hintText: 'https://...',
            ),
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openFromInput,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放此 URL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickLocal,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选本地视频'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('预设示例', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ..._presets.map((p) => Card(
                child: ListTile(
                  title: Text(p.label),
                  subtitle: Text(
                    p.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _open(p.url, title: p.label),
                ),
              )),
        ],
      ),
    );
  }
}

class _Preset {
  const _Preset({required this.label, required this.url});
  final String label;
  final String url;
}

/// 真正承载播放器的页面。负责 controller 生命周期 + 后台播放/截图/PIP 接线。
class _PlayerHost extends StatefulWidget {
  const _PlayerHost({required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<_PlayerHost> createState() => _PlayerHostState();
}

class _PlayerHostState extends State<_PlayerHost> {
  late final KazumiPlayerController _ctrl;
  KazumiAudioHandler? _audioHandler;

  @override
  void initState() {
    super.initState();
    _ctrl = KazumiPlayerController();
    Get.put(_ctrl, tag: 'kazumi_test', permanent: false);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 接入后台播放 / 锁屏控件（失败不阻塞）
    _audioHandler = await ensureKazumiAudioHandler();
    _audioHandler?.attach(_ctrl);
    _audioHandler?.setMediaInfo(title: widget.title);

    await _ctrl.open(url: widget.url);
  }

  Future<void> _doScreenshot() async {
    final r = await ScreenshotService.captureAndSave(_ctrl);
    SmartDialog.showToast(r.ok ? '截图已保存到相册' : (r.errorMessage ?? '保存失败'));
  }

  Future<void> _doPip() async {
    final ok = await PipService.enter();
    if (!ok) SmartDialog.showToast('当前平台不支持小窗模式');
  }

  @override
  void dispose() {
    _audioHandler?.detach();
    Get.delete<KazumiPlayerController>(tag: 'kazumi_test');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // 退出页时自动停止
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: KazumiPlayerView(
          controller: _ctrl,
          title: widget.title,
          onBack: () => Navigator.of(context).maybePop(),
          onScreenshot: _doScreenshot,
          onEnterPip: _doPip,
        ),
      ),
    );
  }
}
