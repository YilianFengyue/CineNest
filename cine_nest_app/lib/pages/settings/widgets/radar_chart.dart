import 'dart:math';
import 'package:flutter/material.dart';

class RadarMetric {
  const RadarMetric({required this.label, required this.value, this.hint = ''});

  final String label;
  final double value; // 0–100
  final String hint;
}

class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.metrics,
    this.size = 220,
    this.gridSteps = 4,
  });

  final List<RadarMetric> metrics;
  final double size;
  final int gridSteps;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('暂无指标数据')),
      );
    }
    return SizedBox(
      width: size + 80,
      height: size + 40,
      child: CustomPaint(
        size: Size(size + 80, size + 40),
        painter: _RadarPainter(
          metrics: metrics,
          gridSteps: gridSteps,
          fillColor: Theme.of(context).colorScheme.primary,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          textColor: Theme.of(context).colorScheme.onSurface,
          subtextColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.metrics,
    required this.gridSteps,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
    required this.subtextColor,
  });

  final List<RadarMetric> metrics;
  final int gridSteps;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;
  final Color subtextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = metrics.length;
    if (n < 3) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(size.width, size.height) / 2 - 30;
    final angleStep = 2 * pi / n;
    final startAngle = -pi / 2;

    Offset vertex(int i, double r) {
      final angle = startAngle + i * angleStep;
      return Offset(cx + r * cos(angle), cy + r * sin(angle));
    }

    // ── 网格 ──
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = gridColor;

    for (int step = 1; step <= gridSteps; step++) {
      final r = radius * step / gridSteps;
      final path = Path();
      for (int i = 0; i <= n; i++) {
        final p = vertex(i % n, r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ── 轴线 ──
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = gridColor.withValues(alpha: 0.5);
    for (int i = 0; i < n; i++) {
      final p = vertex(i, radius);
      canvas.drawLine(Offset(cx, cy), p, axisPaint);
    }

    // ── 数据多边形 ──
    final dataPath = Path();
    for (int i = 0; i <= n; i++) {
      final idx = i % n;
      final v = (metrics[idx].value / 100).clamp(0.0, 1.0);
      final p = vertex(idx, radius * v);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()..color = fillColor.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = fillColor.withValues(alpha: 0.7),
    );

    // ── 数据点 ──
    final dotPaint = Paint()..color = fillColor;
    for (int i = 0; i < n; i++) {
      final v = (metrics[i].value / 100).clamp(0.0, 1.0);
      final p = vertex(i, radius * v);
      canvas.drawCircle(p, 3.5, dotPaint);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
    }

    // ── 标签 ──
    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * angleStep;
      final labelR = radius + 18;
      final lp = Offset(cx + labelR * cos(angle), cy + labelR * sin(angle));

      final tp = TextPainter(
        text: TextSpan(
          text: '${metrics[i].label}\n${metrics[i].value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 60);

      final dx = lp.dx - tp.width / 2;
      final dy = lp.dy - tp.height / 2;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.metrics != metrics || old.fillColor != fillColor;
}
