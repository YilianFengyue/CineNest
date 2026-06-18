import 'package:cine_nest/services/connection_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 扫码连接 PC（F7 扩展）。
///
/// 扫 CineLink「手机连接」页生成的二维码，载荷里带局域网 / Tailscale / ZeroTier
/// 候选地址，交给 [ConnectionService.connectFromQr] 并发探测、自动保存。
/// 成功后 `Get.back(result: true)`，设置页据此刷新输入框。
class ScanConnectPage extends StatefulWidget {
  const ScanConnectPage({super.key});

  @override
  State<ScanConnectPage> createState() => _ScanConnectPageState();
}

class _ScanConnectPageState extends State<ScanConnectPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _probing = false;
  String? _error;
  String? _lastIgnoredRaw;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_probing || _error != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final payload = QrLinkPayload.tryParse(raw);
    if (payload == null) {
      // 同一张无效码只提示一次，避免对着非连接码连环 toast
      if (raw != _lastIgnoredRaw) {
        _lastIgnoredRaw = raw;
        SmartDialog.showToast('这不是 CineNest 连接码');
      }
      return;
    }

    setState(() => _probing = true);
    await _controller.stop();
    final url = await ConnectionService.to.connectFromQr(payload);
    if (!mounted) return;
    if (url != null) {
      SmartDialog.showToast('已连接 ${payload.pcName}');
      Get.back(result: true);
    } else {
      setState(() {
        _probing = false;
        _error = ConnectionService.to.message.value;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _lastIgnoredRaw = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('扫码连接 PC'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, _) => IconButton(
              onPressed: state.isRunning ? _controller.toggleTorch : null,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
              tooltip: '手电筒',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          // 取景框
          Center(
            child: Container(
              width: 252,
              height: 252,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          // 底部状态卡
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _probing
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Obx(() => Text(
                                  ConnectionService.to.message.value,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )),
                          ),
                        ],
                      )
                    : _error != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.wifi_off_rounded,
                                      size: 20, color: cs.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    '连接失败',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _error!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: _retry,
                                  icon: const Icon(Icons.qr_code_scanner_rounded),
                                  label: const Text('重新扫描'),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded,
                                  size: 22, color: cs.primary),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '对准 CineLink「手机连接」页的二维码，'
                                  '连通后自动保存地址',
                                  style: TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相机不可用（权限被拒等）时的占位。
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              denied ? '需要相机权限才能扫码' : '相机启动失败：${error.errorCode.name}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (denied) ...[
              const SizedBox(height: 6),
              const Text(
                '请在系统设置中允许 CineNest 使用相机',
                style: TextStyle(color: Colors.white38, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
