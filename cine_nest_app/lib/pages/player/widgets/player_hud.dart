import 'package:flutter/material.dart';

/// 5 个统一风格的 M3 中央 HUD，挂在 [MaterialVideoControlsThemeData] 的 *IndicatorBuilder 上。
/// 全部 inverseSurface 药丸，避免在亮主题下糊在白底里。

Widget buildBufferingIndicator(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return SizedBox(
    width: 44,
    height: 44,
    child: CircularProgressIndicator(
      strokeWidth: 3,
      color: cs.primary,
      backgroundColor: cs.onInverseSurface.withValues(alpha: 0.16),
    ),
  );
}

Widget buildVolumeIndicator(BuildContext context, double value) {
  final clamped = value.clamp(0.0, 1.0);
  final icon = clamped <= 0.0
      ? Icons.volume_off_rounded
      : clamped < 0.5
          ? Icons.volume_down_rounded
          : Icons.volume_up_rounded;
  return _Pill(
    icon: icon,
    progress: clamped,
    label: '${(clamped * 100).round()}%',
  );
}

Widget buildBrightnessIndicator(BuildContext context, double value) {
  final clamped = value.clamp(0.0, 1.0);
  final icon = clamped < 1.0 / 3.0
      ? Icons.brightness_low_rounded
      : clamped < 2.0 / 3.0
          ? Icons.brightness_medium_rounded
          : Icons.brightness_high_rounded;
  return _Pill(
    icon: icon,
    progress: clamped,
    label: '${(clamped * 100).round()}%',
  );
}

Widget buildSeekIndicator(BuildContext context, Duration delta) {
  final cs = Theme.of(context).colorScheme;
  final isForward = !delta.isNegative;
  final abs = delta.abs();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: cs.inverseSurface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
          color: cs.onInverseSurface,
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          '${isForward ? '+' : '-'}${_formatDuration(abs)}',
          style: TextStyle(
            color: cs.onInverseSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

Widget buildSpeedUpIndicator(BuildContext context, double factor) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: cs.inverseSurface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fast_forward_rounded, color: cs.primary, size: 18),
        const SizedBox(width: 6),
        Text(
          '${factor.toStringAsFixed(factor.truncateToDouble() == factor ? 0 : 1)}x 快进',
          style: TextStyle(
            color: cs.onInverseSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.progress,
    required this.label,
  });

  final IconData icon;
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.inverseSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.onInverseSurface, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: cs.onInverseSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: cs.onInverseSurface.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
