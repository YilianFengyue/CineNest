import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../../router/app_pages.dart';
import '../controller/player_controller.dart';
import '../services/kazumi_audio_handler.dart';
import '../services/pip_service.dart';
import '../services/screenshot_service.dart';
import '../widgets/kazumi_player_view.dart';

/// 本地视频 / 在线 m3u8 播放测试入口（设置 → 播放器测试）。
class LocalPlayerTestPage extends StatefulWidget {
  const LocalPlayerTestPage({super.key});

  @override
  State<LocalPlayerTestPage> createState() => _LocalPlayerTestPageState();
}

class _LocalPlayerTestPageState extends State<LocalPlayerTestPage> {
  final _urlCtrl = TextEditingController();

  /// 这几条是公开测试源，用来区分播放器问题、网络问题和资源站防盗链问题。
  static const _presets = <_Preset>[
    _Preset(
      label: 'Apple HLS Basic (m3u8) · 推荐先试',
      url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
    ),
    _Preset(
      label: 'Mux test stream (m3u8)',
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    ),
    _Preset(
      label: 'Big Buck Bunny (mp4)',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
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
          ..._presets.map(
            (p) => Card(
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
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '小贴士：\n'
                '· m3u8 会先走原生播放器，失败时可在播放器错误条点“重试”或“浏览器”。\n'
                '· 如果浏览器能播但原生不能播，优先检查 Referer/Cookie/防盗链，再决定是否换源。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ),
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

/// 真正承载播放器的页面：上半屏 16:9 视频 + 下半屏占位（详情/选集 Step 4 接入）。
///
/// 全屏时切换为视频铺满。
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
  Worker? _errorWorker;
  String _lastShownError = '';

  @override
  void initState() {
    super.initState();
    _ctrl = KazumiPlayerController();
    Get.put(_ctrl, tag: 'kazumi_test', permanent: false);

    // 错误反馈：致命错误一变就 toast（测试页保留，便于肉眼盯日志）
    _errorWorker = ever<String>(_ctrl.fatalError, (e) {
      if (e.isEmpty || e == _lastShownError) return;
      _lastShownError = e;
      SmartDialog.showToast(_friendlyError(e));
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _audioHandler = await ensureKazumiAudioHandler();
    _audioHandler?.attach(_ctrl);
    _audioHandler?.setMediaInfo(title: widget.title);
    await _ctrl.open(url: widget.url);
  }

  String _friendlyError(String raw) {
    if (raw.contains('Failed to resolve hostname') ||
        raw.contains('No address associated')) {
      return '源地址 DNS 解析失败，请确认域名或换源';
    }
    if (raw.contains('Failed to open')) {
      return '源打开失败，已补浏览器请求头；可重试或浏览器播放';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
  }

  Future<void> _doScreenshot() async {
    final r = await ScreenshotService.captureAndSave(_ctrl);
    SmartDialog.showToast(r.ok ? '截图已保存到相册' : (r.errorMessage ?? '保存失败'));
  }

  Future<void> _doPip() async {
    final ok = await PipService.enter();
    if (!ok) SmartDialog.showToast('当前平台不支持小窗模式');
  }

  Future<void> _retryOpen() async {
    await _ctrl.open(url: widget.url);
  }

  void _openInWebView() {
    Get.toNamed(
      Routes.webviewPlayer,
      arguments: {'url': widget.url, 'title': widget.title},
    );
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _audioHandler?.detach();
    Get.delete<KazumiPlayerController>(tag: 'kazumi_test');
    super.dispose();
  }

  Widget _buildDetailPlaceholder() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(
            height: 48,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicatorPadding: EdgeInsets.symmetric(horizontal: 6),
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(text: '选集'),
                Tab(text: '评论'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '选集占位\n（Step 4 接入真实选集 / 换源）',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '评论占位\n（Step 4 用假数据接入）',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fullscreen = _ctrl.isFullscreen.value;
      return PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _ctrl.isFullscreen.value) {
            _ctrl.setFullscreen(false);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          // 全屏：不留 SafeArea，视频铺满
          // inline：顶部留 SafeArea 让出状态栏，底部不留（被 placeholder 覆盖）
          body: fullscreen
              ? KazumiPlayerView(
                  controller: _ctrl,
                  title: widget.title,
                  onBack: () => _ctrl.setFullscreen(false),
                  onScreenshot: _doScreenshot,
                  onEnterPip: _doPip,
                  onRetry: _retryOpen,
                  onOpenInWebView: _openInWebView,
                )
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: KazumiPlayerView(
                            controller: _ctrl,
                            title: widget.title,
                            onBack: () => Navigator.of(context).maybePop(),
                            onScreenshot: _doScreenshot,
                            onEnterPip: _doPip,
                            onRetry: _retryOpen,
                            onOpenInWebView: _openInWebView,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: _buildDetailPlaceholder(),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    });
  }
}
