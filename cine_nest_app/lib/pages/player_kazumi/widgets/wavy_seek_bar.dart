import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Android 16 媒体控件风格的波浪进度条。
///
/// - 播放中：已播区域是缓慢向前滚动的波浪线
/// - 暂停 / 拖动中：波浪平滑压平成直线
/// - 拇指：竖向小圆杆；未播区域：细横线 + 末端小圆点
///
/// 自带拖拽/点击 seek 手势，回调全部以 [Duration] 表达。
class WavySeekBar extends StatefulWidget {
  const WavySeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.playing,
    required this.activeColor,
    this.buffered = Duration.zero,
    this.inactiveColor = Colors.white24,
    this.bufferedColor,
    this.height = 24,
    this.strokeWidth = 3,
    this.amplitude = 3,
    this.wavelength = 24,
    this.waveCycle = const Duration(milliseconds: 900),
    this.thumbWidth,
    this.thumbHeight,
    this.onSeekStart,
    this.onSeekPreview,
    this.onSeekEnd,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool playing;

  final Color activeColor;
  final Color inactiveColor;
  final Color? bufferedColor;

  final double height;
  final double strokeWidth;

  /// 波浪振幅（波峰到中线的高度，越大波浪越"高"）
  final double amplitude;

  /// 波长（一个完整波浪的横向长度，越小波浪越密）
  final double wavelength;

  /// 波浪滚动一个波长所需时间（越短滚得越快）
  final Duration waveCycle;

  /// 拇指竖条宽度，缺省 = strokeWidth + 1.5
  final double? thumbWidth;

  /// 拇指竖条高度，缺省 ≈ 振幅*2 + 线宽*3.2（不超过控件高度）
  final double? thumbHeight;

  final VoidCallback? onSeekStart;
  final ValueChanged<Duration>? onSeekPreview;
  final ValueChanged<Duration>? onSeekEnd;

  @override
  State<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends State<WavySeekBar>
    with TickerProviderStateMixin {
  /// 波浪相位：一个周期 = 波形向前滚动一个波长。
  late final AnimationController _phase;

  /// 振幅过渡：播放 1 ←→ 暂停 0。
  late final AnimationController _amp;

  bool _dragging = false;
  double _dragRatio = 0;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: widget.waveCycle,
    );
    _amp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.playing ? 1 : 0,
    );
    _amp.addStatusListener((status) {
      // 压平后停掉相位动画，省电
      if (status == AnimationStatus.dismissed) _phase.stop();
    });
    if (widget.playing) _phase.repeat();
  }

  @override
  void didUpdateWidget(WavySeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waveCycle != oldWidget.waveCycle) {
      _phase.duration = widget.waveCycle;
      if (_phase.isAnimating) _phase.repeat();
    }
    final waveOn = widget.playing && !_dragging;
    if (waveOn) {
      if (!_phase.isAnimating) _phase.repeat();
      _amp.forward();
    } else {
      _amp.reverse();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _amp.dispose();
    super.dispose();
  }

  bool get _seekable =>
      widget.duration > Duration.zero && widget.onSeekEnd != null;

  double _ratioAt(Offset localPosition) {
    final w = context.size?.width ?? 0;
    if (w <= 0) return 0;
    return (localPosition.dx / w).clamp(0.0, 1.0);
  }

  Duration _durationAt(double ratio) => Duration(
        milliseconds: (widget.duration.inMilliseconds * ratio).round(),
      );

  void _startDrag(Offset localPosition) {
    setState(() {
      _dragging = true;
      _dragRatio = _ratioAt(localPosition);
    });
    _amp.reverse();
    widget.onSeekStart?.call();
    widget.onSeekPreview?.call(_durationAt(_dragRatio));
  }

  void _updateDrag(Offset localPosition) {
    setState(() => _dragRatio = _ratioAt(localPosition));
    widget.onSeekPreview?.call(_durationAt(_dragRatio));
  }

  void _endDrag() {
    setState(() => _dragging = false);
    widget.onSeekEnd?.call(_durationAt(_dragRatio));
    if (widget.playing) {
      _phase.repeat();
      _amp.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final ratio = _dragging
        ? _dragRatio
        : (totalMs > 0
            ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0);
    final bufferedRatio = totalMs > 0
        ? (widget.buffered.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _seekable
          ? (d) {
              widget.onSeekStart?.call();
              final r = _ratioAt(d.localPosition);
              widget.onSeekPreview?.call(_durationAt(r));
              setState(() => _dragRatio = r);
              widget.onSeekEnd?.call(_durationAt(r));
            }
          : null,
      onHorizontalDragStart:
          _seekable ? (d) => _startDrag(d.localPosition) : null,
      onHorizontalDragUpdate:
          _seekable ? (d) => _updateDrag(d.localPosition) : null,
      onHorizontalDragEnd: _seekable ? (_) => _endDrag() : null,
      onHorizontalDragCancel: _seekable ? _endDrag : null,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WavyBarPainter(
            progress: ratio,
            buffered: bufferedRatio,
            phase: _phase,
            amp: _amp,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
            bufferedColor: widget.bufferedColor,
            strokeWidth: widget.strokeWidth,
            amplitude: widget.amplitude,
            wavelength: widget.wavelength,
            thumbWidth: widget.thumbWidth,
            thumbHeight: widget.thumbHeight,
          ),
        ),
      ),
    );
  }
}

class _WavyBarPainter extends CustomPainter {
  _WavyBarPainter({
    required this.progress,
    required this.buffered,
    required this.phase,
    required this.amp,
    required this.activeColor,
    required this.inactiveColor,
    required this.bufferedColor,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
    required this.thumbWidth,
    required this.thumbHeight,
  }) : super(repaint: Listenable.merge([phase, amp]));

  final double progress;
  final double buffered;
  final Animation<double> phase;
  final Animation<double> amp;
  final Color activeColor;
  final Color inactiveColor;
  final Color? bufferedColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double? thumbWidth;
  final double? thumbHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final w = size.width;
    if (w <= 0) return;

    final thumbW = thumbWidth ?? (strokeWidth + 1.5);
    final thumbH = math.min(
      size.height,
      thumbHeight ?? (amplitude * 2 + strokeWidth * 3.2),
    );
    final thumbX = (progress * w).clamp(thumbW / 2, w - thumbW / 2);
    // 仅右侧未播横线与拇指之间留呼吸间隙；左侧波浪直接与拇指相接
    final gap = thumbW / 2 + strokeWidth + 1;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── 已播区域：波浪线（振幅随播放状态过渡到 0 即直线），
    //    末端画到拇指中心，被后绘的拇指盖住 → 视觉上相接无缝 ──
    final activeEnd = thumbX;
    if (activeEnd > 0) {
      final a = amp.value * amplitude;
      if (a < 0.15) {
        canvas.drawLine(Offset(0, midY), Offset(activeEnd, midY), activePaint);
      } else {
        final path = Path();
        // 相位随时间增大 → 波形向前（右）滚动
        final shift = phase.value * wavelength;
        const step = 2.0;
        for (double x = 0; x <= activeEnd; x += step) {
          final y =
              midY + a * math.sin(2 * math.pi * (x - shift) / wavelength);
          if (x == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, activePaint);
      }
    }

    // ── 未播区域：细横线 ──
    final inactiveStart = thumbX + gap;
    if (inactiveStart < w) {
      // 缓冲段画得稍亮
      final bufferedEnd = (buffered * w).clamp(inactiveStart, w);
      if (bufferedColor != null && bufferedEnd > inactiveStart) {
        canvas.drawLine(
          Offset(inactiveStart, midY),
          Offset(bufferedEnd, midY),
          Paint()
            ..color = bufferedColor!
            ..strokeWidth = strokeWidth * 0.8
            ..strokeCap = StrokeCap.round,
        );
        if (bufferedEnd < w) {
          canvas.drawLine(
            Offset(bufferedEnd, midY),
            Offset(w, midY),
            Paint()
              ..color = inactiveColor
              ..strokeWidth = strokeWidth * 0.8
              ..strokeCap = StrokeCap.round,
          );
        }
      } else {
        canvas.drawLine(
          Offset(inactiveStart, midY),
          Offset(w, midY),
          Paint()
            ..color = inactiveColor
            ..strokeWidth = strokeWidth * 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
      // 末端小圆点（轨道终点标记）
      canvas.drawCircle(
        Offset(w - strokeWidth / 2, midY),
        strokeWidth * 0.7,
        Paint()..color = inactiveColor,
      );
    }

    // ── 拇指：竖向小圆杆 ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, midY),
          width: thumbW,
          height: thumbH,
        ),
        Radius.circular(thumbW / 2),
      ),
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(_WavyBarPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      old.strokeWidth != strokeWidth ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength ||
      old.thumbWidth != thumbWidth ||
      old.thumbHeight != thumbHeight;
}
