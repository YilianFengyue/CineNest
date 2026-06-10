import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../../pages/player_kazumi/controller/player_controller.dart';
import '../../../pages/player_kazumi/services/kazumi_audio_handler.dart';
import '../../../pages/player_kazumi/services/pip_service.dart';
import '../../../pages/player_kazumi/services/screenshot_service.dart';
import '../../../pages/player_kazumi/widgets/kazumi_player_view.dart';
import '../../../router/app_pages.dart';
import '../models/media_models.dart';

class AggregatorPlayerHostPage extends StatefulWidget {
  const AggregatorPlayerHostPage({super.key, required this.session});

  final AggregatorPlaySession session;

  @override
  State<AggregatorPlayerHostPage> createState() =>
      _AggregatorPlayerHostPageState();
}

class _AggregatorPlayerHostPageState extends State<AggregatorPlayerHostPage> {
  late final KazumiPlayerController _ctrl;
  KazumiAudioHandler? _audioHandler;
  Worker? _errorWorker;
  String _lastShownError = '';

  @override
  void initState() {
    super.initState();
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

  String get _tag =>
      'aggregator_player_${widget.session.source}_${widget.session.remoteId}';

  Future<void> _bootstrap() async {
    _audioHandler = await ensureKazumiAudioHandler();
    _audioHandler?.attach(_ctrl);
    _audioHandler?.setMediaInfo(title: widget.session.title);
    await _openCurrent();
  }

  Future<void> _openCurrent() async {
    await _ctrl.open(
      url: widget.session.playUrl,
      headers: widget.session.headers,
      startAt: widget.session.resumePosition,
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

  void _openInWebView() {
    Get.toNamed(
      Routes.webviewPlayer,
      arguments: {'url': widget.session.playUrl, 'title': widget.session.title},
    );
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _audioHandler?.detach();
    Get.delete<KazumiPlayerController>(tag: _tag);
    super.dispose();
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
          body: fullscreen
              ? KazumiPlayerView(
                  controller: _ctrl,
                  title: widget.session.title,
                  onBack: () => _ctrl.setFullscreen(false),
                  onScreenshot: _doScreenshot,
                  onEnterPip: _doPip,
                  onRetry: _openCurrent,
                  onOpenInWebView: _openInWebView,
                )
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: KazumiPlayerView(
                          controller: _ctrl,
                          title: widget.session.title,
                          onBack: () => Navigator.of(context).maybePop(),
                          onScreenshot: _doScreenshot,
                          onEnterPip: _doPip,
                          onRetry: _openCurrent,
                          onOpenInWebView: _openInWebView,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.surface,
                          child: _SessionPanel(session: widget.session),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    });
  }

  String _friendlyError(String raw) {
    if (raw.contains('超时') || raw.contains('TimeoutException')) {
      return '起播超时，可重试或返回换源';
    }
    if (raw.contains('403') || raw.contains('401')) {
      return '源鉴权失败，可能需要 Referer/Cookie';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.session});

  final AggregatorPlaySession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          session.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text('${session.sourceName} · 第 ${session.episodeIndex + 1} 集'),
        const SizedBox(height: 16),
        Text('播放地址', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        SelectableText(session.playUrl, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
