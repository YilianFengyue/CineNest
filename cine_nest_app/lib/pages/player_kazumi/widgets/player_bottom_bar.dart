import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';
import 'wavy_seek_bar.dart';

/// 底部控制栏。
///
/// - [compact] = true：内嵌模式。两行：① 细进度条 ② 一行 ▶ 时间 ⛶
/// - [compact] = false：全屏模式。进度条 + 完整按钮行（倍速/比例/截图/PIP/全屏）
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    super.key,
    required this.controller,
    this.compact = false,
    this.onScreenshot,
    this.onEnterPip,
  });

  final KazumiPlayerController controller;
  final bool compact;
  final Future<void> Function()? onScreenshot;
  final Future<void> Function()? onEnterPip;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  Widget _progressBar(BuildContext context, {required bool thin}) {
    return Obx(
      () => WavySeekBar(
        position: controller.position.value,
        buffered: controller.buffer.value,
        duration: controller.duration.value,
        playing: controller.playing.value,
        // ── 微调旋钮 ──────────────────────────────────────
        height: thin ? 16 : 22, // 控件总高（手势热区）
        strokeWidth: thin ? 2.2 : 3.0, // 线粗
        amplitude: thin ? 2.2 : 3.0, // 波浪振幅（波峰高度）
        wavelength: thin ? 24 : 32, // 波长（越小越密）
        waveCycle: const Duration(milliseconds: 1800), // 滚动速度（越短越快）
        thumbWidth: thin ? 3.5 : 4.5, // 竖条宽
        thumbHeight: thin ? 16 : 20, // 竖条高
        // ─────────────────────────────────────────────────
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Colors.white24,
        bufferedColor: Colors.white38,
        // beginSeekPreview 内部记住播放状态并暂停，commit 时按原状态恢复
        onSeekStart: controller.beginSeekPreview,
        onSeekPreview: (d) {
          controller.seekTargetMs.value = d.inMilliseconds;
          controller.showSeekHud.value = true;
        },
        onSeekEnd: (_) => controller.commitSeekPreview(),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 6, right: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          // ▶ 播放/暂停
          Obx(
            () => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: Icon(
                controller.playing.value ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
              onPressed: controller.playOrPause,
            ),
          ),
          const SizedBox(width: 4),
          // 进度条（wavy，吃剩余空间）
          Expanded(child: _progressBar(context, thin: true)),
          const SizedBox(width: 6),
          // 时间
          Obx(() {
            final pos = _formatDuration(controller.position.value);
            final dur = _formatDuration(controller.duration.value);
            return Text(
              '$pos/$dur',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            );
          }),
          // 全屏
          Obx(
            () => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: Icon(
                controller.isFullscreen.value
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
              onPressed: controller.toggleFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _progressBar(context, thin: false),
          ),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Obx(
                  () => IconButton(
                    icon: Icon(
                      controller.playing.value ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: controller.playOrPause,
                  ),
                ),
                Obx(() {
                  final pos = _formatDuration(controller.position.value);
                  final dur = _formatDuration(controller.duration.value);
                  return Text(
                    '$pos / $dur',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }),
                const Spacer(),
                Obx(
                  () => _SmallChip(
                    label: _speedLabel(controller.speed.value),
                    onTap: () => _cycleSpeed(controller),
                  ),
                ),
                const SizedBox(width: 4),
                Obx(
                  () => _SmallChip(
                    label: _aspectLabel(controller.aspectRatioType.value),
                    onTap: controller.cycleAspectRatio,
                  ),
                ),
                const SizedBox(width: 4),
                _ShaderPopup(controller: controller),
                if (onScreenshot != null)
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                    ),
                    tooltip: '截图',
                    onPressed: () {
                      controller.showControlsTemporarily();
                      onScreenshot!();
                    },
                  ),
                if (onEnterPip != null)
                  IconButton(
                    icon: const Icon(
                      Icons.picture_in_picture_alt,
                      color: Colors.white,
                    ),
                    tooltip: '小窗',
                    onPressed: () {
                      controller.showControlsTemporarily();
                      onEnterPip!();
                    },
                  ),
                Obx(
                  () => IconButton(
                    icon: Icon(
                      controller.isFullscreen.value
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: controller.toggleFullscreen,
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
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  static String _speedLabel(double s) {
    if (s == s.toInt()) return '${s.toInt()}x';
    return '${s.toStringAsFixed(2)}x';
  }

  static String _aspectLabel(int type) {
    switch (type) {
      case 2:
        return '填充';
      case 3:
        return '拉伸';
      default:
        return '原始';
    }
  }

  static void _cycleSpeed(KazumiPlayerController c) {
    const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];
    final cur = c.speed.value;
    var idx = presets.indexWhere((s) => (s - cur).abs() < 0.01);
    idx = (idx + 1) % presets.length;
    c.setSpeed(presets[idx]);
  }
}

class _ShaderPopup extends StatelessWidget {
  const _ShaderPopup({required this.controller});
  final KazumiPlayerController controller;

  static const _labels = ['关闭', '效率档', '质量档'];
  static const _types = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.superResolution.value;
      final isOn = current > 1;
      return PopupMenuButton<int>(
        onSelected: controller.setShader,
        offset: const Offset(0, -160),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (_) => [
          for (int i = 0; i < 3; i++)
            PopupMenuItem(
              value: _types[i],
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: current == _types[i]
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  fontWeight: current == _types[i]
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isOn
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                : Colors.white12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '超分辨率',
            style: TextStyle(
              color: isOn
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      );
    });
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
