import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';

/// 播放器底部控制栏：进度条 + 播放/暂停 + 时间 + 倍速 + 比例 + 截图 + PIP + 全屏。
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    super.key,
    required this.controller,
    this.onScreenshot,
    this.onEnterPip,
  });

  final KazumiPlayerController controller;
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

  @override
  Widget build(BuildContext context) {
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
          // 进度条
          Obx(() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ProgressBar(
                  progress: controller.position.value,
                  buffered: controller.buffer.value,
                  total: controller.duration.value,
                  timeLabelLocation: TimeLabelLocation.none,
                  barHeight: 3.0,
                  thumbRadius: 6.0,
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
                ),
              )),

          // 控件行
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }),
                const Spacer(),
                // 倍速 chip
                Obx(() => _SmallChip(
                      label: '${controller.speed.value.toStringAsFixed(controller.speed.value == controller.speed.value.toInt() ? 0 : 2)}x',
                      onTap: () => _cycleSpeed(controller),
                    )),
                const SizedBox(width: 4),
                // 比例 chip
                Obx(() => _SmallChip(
                      label: _aspectLabel(controller.aspectRatioType.value),
                      onTap: controller.cycleAspectRatio,
                    )),
                if (onScreenshot != null)
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                    tooltip: '截图',
                    onPressed: () {
                      controller.showControlsTemporarily();
                      onScreenshot!();
                    },
                  ),
                if (onEnterPip != null)
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
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
