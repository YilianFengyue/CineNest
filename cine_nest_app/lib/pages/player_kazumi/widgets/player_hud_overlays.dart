import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';

/// 浮层集合：音量 HUD、亮度 HUD、倍速 HUD、Seek 预览 HUD。
///
/// 这里所有 widget 都用 Obx 单独 wrap，避免一个浮层变化让整个播放器重建。
class PlayerHudOverlays extends StatelessWidget {
  const PlayerHudOverlays({super.key, required this.controller});

  final KazumiPlayerController controller;

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 倍速 HUD（顶部中央）
          Obx(() => AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: controller.showSpeedHud.value ? 1 : 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: _HudPill(
                      icon: Icons.fast_forward,
                      text: '${controller.speed.value.toStringAsFixed(1)}x',
                    ),
                  ),
                ),
              )),

          // Seek HUD（中央）
          Obx(() => AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: controller.showSeekHud.value ? 1 : 0,
                child: Center(
                  child: _HudPill(
                    icon: controller.seekDirection.value > 0
                        ? Icons.fast_forward
                        : controller.seekDirection.value < 0
                            ? Icons.fast_rewind
                            : Icons.swap_horiz,
                    text:
                        '${_formatMs(controller.seekTargetMs.value)} / ${_formatMs(controller.duration.value.inMilliseconds)}',
                  ),
                ),
              )),

          // 音量 HUD（右侧）
          Obx(() => AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: controller.showVolumeHud.value ? 1 : 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: _VerticalLevelBar(
                      icon: controller.volume.value <= 0
                          ? Icons.volume_off
                          : controller.volume.value < 50
                              ? Icons.volume_down
                              : Icons.volume_up,
                      value: controller.volume.value / 100,
                      label: '${controller.volume.value.round()}',
                    ),
                  ),
                ),
              )),

          // 亮度 HUD（左侧）
          Obx(() => AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: controller.showBrightnessHud.value ? 1 : 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: _VerticalLevelBar(
                      icon: controller.brightness.value < 0.33
                          ? Icons.brightness_low
                          : controller.brightness.value < 0.66
                              ? Icons.brightness_medium
                              : Icons.brightness_high,
                      value: controller.brightness.value,
                      label: '${(controller.brightness.value * 100).round()}',
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _VerticalLevelBar extends StatelessWidget {
  const _VerticalLevelBar({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            width: 4,
            child: RotatedBox(
              quarterTurns: 3,
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
