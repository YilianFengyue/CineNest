import 'package:flutter/material.dart';

/// 三点呼吸式「正在思考」指示器。
///
/// 三个点依次提亮，营造打字 / 思考观感；颜色走 [colorScheme]，零硬编码。
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color, this.size = 7});

  final Color? color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : widget.size * 0.6),
            child: AnimatedBuilder(
              animation: _ac,
              builder: (_, _) {
                // 每个点相位错开 1/3，亮度在 0.3~1.0 之间脉动。
                final phase = (_ac.value + i / 3) % 1.0;
                final t = (phase < 0.5 ? phase : 1 - phase) * 2; // 0→1→0
                return Opacity(
                  opacity: 0.3 + 0.7 * t,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
