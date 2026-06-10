import 'package:flutter/material.dart';

import '../models/source_health.dart';

class SourceHealthChip extends StatelessWidget {
  const SourceHealthChip({super.key, this.health});

  final SourceHealthSnapshot? health;

  @override
  Widget build(BuildContext context) {
    final level = health?.level ?? SourceHealthLevel.unknown;
    final color = switch (level) {
      SourceHealthLevel.good => Colors.green,
      SourceHealthLevel.slow => Colors.orange,
      SourceHealthLevel.bad => Colors.red,
      SourceHealthLevel.unknown => Theme.of(context).colorScheme.outline,
    };
    final text = switch (level) {
      SourceHealthLevel.good => '${health?.averageElapsedMs ?? '-'}ms',
      SourceHealthLevel.slow => '慢 ${health?.averageElapsedMs ?? '-'}ms',
      SourceHealthLevel.bad => '坏源',
      SourceHealthLevel.unknown => '未知',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
