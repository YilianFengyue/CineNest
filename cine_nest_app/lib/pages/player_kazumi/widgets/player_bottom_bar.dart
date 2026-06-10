import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';

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
    return Obx(() => ProgressBar(
          progress: controller.position.value,
          buffered: controller.buffer.value,
          total: controller.duration.value,
          timeLabelLocation: TimeLabelLocation.none,
          // 关键：ProgressBar 实际占高 ≈ max(barHeight, thumbRadius*2)
          // compact 用 3.5 → 总高 ~7px；full 用 5 → 总高 ~10px
          barHeight: thin ? 2.0 : 3.0,
          thumbRadius: thin ? 3.5 : 5.0,
          baseBarColor: Colors.white24,
          bufferedBarColor: Colors.white38,
          progressBarColor: Theme.of(context).colorScheme.primary,
          thumbColor: Theme.of(context).colorScheme.primary,
          onDragStart: (_) {
            controller.pause();
            controller.beginSeekPreview();
          },
          onDragUpdate: (d) {
            controller.seekTargetMs.value = d.timeStamp.inMilliseconds;
            controller.showSeekHud.value = true;
          },
          onDragEnd: () {
            controller.commitSeekPreview();
            controller.play();
          },
          onSeek: (to) => controller.seekTo(to),
        ));
  }

  Widget _buildCompact(BuildContext context) {
    // inline 模式：视频是 AspectRatio 框，不在屏底，不能用 MediaQuery padding
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条：左右贴边，不再加 horizontal padding
          _progressBar(context, thin: true),
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Obx(() => IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 26, height: 26),
                      icon: Icon(
                        controller.playing.value
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: controller.playOrPause,
                    )),
                const SizedBox(width: 4),
                Obx(() {
                  final pos = _formatDuration(controller.position.value);
                  final dur = _formatDuration(controller.duration.value);
                  return Text(
                    '$pos / $dur',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11),
                  );
                }),
                const Spacer(),
                Obx(() => IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 26, height: 26),
                      icon: Icon(
                        controller.isFullscreen.value
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: controller.toggleFullscreen,
                    )),
              ],
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
                Obx(() => IconButton(
                      icon: Icon(
                        controller.playing.value
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: controller.playOrPause,
                    )),
                Obx(() {
                  final pos = _formatDuration(controller.position.value);
                  final dur = _formatDuration(controller.duration.value);
                  return Text(
                    '$pos / $dur',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  );
                }),
                const Spacer(),
                Obx(() => _SmallChip(
                      label: _speedLabel(controller.speed.value),
                      onTap: () => _cycleSpeed(controller),
                    )),
                const SizedBox(width: 4),
                Obx(() => _SmallChip(
                      label: _aspectLabel(controller.aspectRatioType.value),
                      onTap: controller.cycleAspectRatio,
                    )),
                if (onScreenshot != null)
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Colors.white),
                    tooltip: '截图',
                    onPressed: () {
                      controller.showControlsTemporarily();
                      onScreenshot!();
                    },
                  ),
                if (onEnterPip != null)
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt,
                        color: Colors.white),
                    tooltip: '小窗',
                    onPressed: () {
                      controller.showControlsTemporarily();
                      onEnterPip!();
                    },
                  ),
                Obx(() => IconButton(
                      icon: Icon(
                        controller.isFullscreen.value
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: controller.toggleFullscreen,
                    )),
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
