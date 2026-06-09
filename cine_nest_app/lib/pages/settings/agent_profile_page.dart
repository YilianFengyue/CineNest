import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/services/agent_memory_service.dart';
import 'package:cine_nest/pages/settings/widgets/radar_chart.dart';
import 'package:cine_nest/pages/settings/widgets/profile_graph_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 模板枚举
// ─────────────────────────────────────────────────────────────────────────────

enum _Template {
  dashboard('仪表盘', Icons.dashboard_rounded),
  timeline('时间轴', Icons.timeline_rounded),
  graph('知识图谱', Icons.hub_rounded);

  const _Template(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 主页
// ─────────────────────────────────────────────────────────────────────────────

class AgentProfilePage extends StatefulWidget {
  const AgentProfilePage({super.key});

  @override
  State<AgentProfilePage> createState() => _AgentProfilePageState();
}

class _AgentProfilePageState extends State<AgentProfilePage> {
  final _service = AgentMemoryService();
  late Future<Map<String, dynamic>> _future;
  _Template _tpl = _Template.dashboard;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchProfile();
  }

  Future<void> _sync() async {
    SmartDialog.showLoading(msg: '正在同步本地画像…');
    try {
      await _service.syncLocalSignals();
      final profile = await _service.fetchProfile();
      if (!mounted) return;
      setState(() {
        _future = Future.value(profile);
      });
      SmartDialog.showToast('画像已同步');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _rebuild() async {
    SmartDialog.showLoading(msg: '正在重建画像…');
    try {
      final profile = await _service.rebuildProfile();
      if (!mounted) return;
      setState(() {
        _future = Future.value(profile);
      });
      SmartDialog.showToast('画像已重建');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent 长期画像'),
        actions: [
          IconButton(
            tooltip: '同步本地历史',
            onPressed: _sync,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: '重建画像',
            onPressed: _rebuild,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.data ?? const {};
          return Column(
            children: [
              _TemplateSwitcher(
                value: _tpl,
                onChanged: (v) => setState(() => _tpl = v),
              ),
              Expanded(
                child: switch (_tpl) {
                  _Template.dashboard => _DashboardView(data: data),
                  _Template.timeline => _TimelineView(data: data),
                  _Template.graph => _GraphView(data: data),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 模板切换条
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateSwitcher extends StatelessWidget {
  const _TemplateSwitcher({required this.value, required this.onChanged});

  final _Template value;
  final ValueChanged<_Template> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SegmentedButton<_Template>(
        segments: [
          for (final t in _Template.values)
            ButtonSegment(
              value: t,
              label: Text(t.label),
              icon: Icon(t.icon, size: 18),
            ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: cs.primaryContainer,
          selectedForegroundColor: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 模板 1: Dashboard 仪表盘
// ═════════════════════════════════════════════════════════════════════════════

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tags = _asList(data['taste_tags']);
    final avoidTags = _asList(data['avoid_tags']);
    final metrics = _asList(data['radar_metrics']);
    final sources = _asList(data['source_distribution']);
    final formats = _asList(data['format_distribution']);
    final stats = _asMap(data['stats']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── 摘要 ──
        Text(
          data['summary']?.toString() ?? '暂无画像',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // ── 统计行 ──
        Row(
          children: [
            _StatCard(
              label: '记忆',
              value: stats['memory_count'],
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: '历史',
              value: stats['history_count'],
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: '收藏',
              value: stats['favorite_count'],
              color: cs.secondary,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── 雷达图 ──
        if (metrics.isNotEmpty) ...[
          _SectionTitle('观影维度'),
          Center(
            child: RadarChart(
              metrics: metrics.map((m) {
                final map = _asMap(m);
                return RadarMetric(
                  label: map['label']?.toString() ?? '',
                  value: double.tryParse('${map['value'] ?? 0}') ?? 0,
                  hint: map['hint']?.toString() ?? '',
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 偏好标签 ──
        if (tags.isNotEmpty) ...[
          _SectionTitle('偏好标签'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in tags) _TagChip.taste(t)],
          ),
          const SizedBox(height: 16),
        ],

        // ── 避雷标签 ──
        if (avoidTags.isNotEmpty) ...[
          _SectionTitle('避雷标签'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in avoidTags) _TagChip.avoid(t)],
          ),
          const SizedBox(height: 16),
        ],

        // ── 片源分布 ──
        if (sources.isNotEmpty) ...[
          _SectionTitle('片源分布'),
          _HorizontalBarList(items: sources, color: cs.primary),
          const SizedBox(height: 16),
        ],

        // ── 格式分布 ──
        if (formats.isNotEmpty) ...[
          _SectionTitle('格式分布'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in formats) _FormatChip(item: _asMap(f))],
          ),
          const SizedBox(height: 16),
        ],

        // ── 高频片名 ──
        if ((stats['top_titles'] as List?)?.isNotEmpty == true) ...[
          _SectionTitle('高频片名'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in stats['top_titles'] as List)
                Chip(
                  label: Text('《${t.toString()}》'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 模板 2: Timeline 时间轴
// ═════════════════════════════════════════════════════════════════════════════

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeline = _asList(data['timeline']);
    final stats = _asMap(data['stats']);

    if (timeline.isEmpty) {
      return const Center(child: Text('暂无时间线数据，先同步观看历史'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        // 顶部摘要卡
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['summary']?.toString() ?? '暂无画像',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '共 ${stats['memory_count'] ?? 0} 条记忆 · '
            '${stats['history_count'] ?? 0} 历史 · '
            '${stats['favorite_count'] ?? 0} 收藏',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 时间轴
        for (int i = 0; i < timeline.length; i++)
          _TimelineItem(
            item: _asMap(timeline[i]),
            isFirst: i == 0,
            isLast: i == timeline.length - 1,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    this.isFirst = false,
    this.isLast = false,
  });

  final Map<String, dynamic> item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final type = item['type']?.toString() ?? '';
    final payload = _asMap(item['payload']);
    final cover = payload['cover']?.toString() ?? '';
    final isFav = type == 'favorite';
    final dotColor = isFav ? cs.secondary : cs.primary;
    final timeStr = _formatTimelineAt(item['at']?.toString() ?? '');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间轴线
          SizedBox(
            width: 48,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: _VerticalLine(color: cs.outlineVariant)),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(
                      color: dotColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: _VerticalLine(color: cs.outlineVariant)),
              ],
            ),
          ),
          // 右侧内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (cover.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          width: 44,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 44,
                            height: 60,
                            color: cs.surfaceContainerHigh,
                            child: Icon(
                              Icons.movie_rounded,
                              size: 20,
                              color: cs.outline,
                            ),
                          ),
                        ),
                      ),
                    if (cover.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 14,
                                color: dotColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((item['subtitle']?.toString() ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item['subtitle']!.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              timeStr,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.outline,
                              ),
                            ),
                          ),
                        ],
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

class _VerticalLine extends StatelessWidget {
  const _VerticalLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(width: 1.5, color: color.withValues(alpha: 0.4)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 模板 3: Graph 知识图谱
// ═════════════════════════════════════════════════════════════════════════════

class _GraphView extends StatelessWidget {
  const _GraphView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nodes = _asList(data['graph_nodes']).map(_asMap).toList();
    final edges = _asList(data['graph_edges']).map(_asMap).toList();
    final tags = _asList(data['taste_tags']);
    final avoidTags = _asList(data['avoid_tags']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 摘要
        Text(
          data['summary']?.toString() ?? '暂无画像',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),

        // 图谱 WebView
        ProfileGraphWebView(nodes: nodes, edges: edges),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '拖拽/缩放探索图谱 · 节点越大权重越高',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 图例
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _LegendDot(color: const Color(0xFF6750A4), label: '用户'),
            _LegendDot(color: const Color(0xFF0097A7), label: '类型'),
            _LegendDot(color: const Color(0xFF1976D2), label: '片源'),
            _LegendDot(color: const Color(0xFFF57C00), label: '影视'),
            _LegendDot(color: const Color(0xFF388E3C), label: '特征'),
            _LegendDot(color: const Color(0xFFD32F2F), label: '风险'),
          ],
        ),
        const SizedBox(height: 18),

        // 标签区
        if (tags.isNotEmpty) ...[
          _SectionTitle('偏好标签'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in tags) _TagChip.taste(t)],
          ),
          const SizedBox(height: 12),
        ],
        if (avoidTags.isNotEmpty) ...[
          _SectionTitle('避雷标签'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in avoidTags) _TagChip.avoid(t)],
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 共享原子组件
// ═════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '${value ?? 0}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip._({required this.item, required this.isAvoid});

  factory _TagChip.taste(Object? item) =>
      _TagChip._(item: _asMap(item), isAvoid: false);
  factory _TagChip.avoid(Object? item) =>
      _TagChip._(item: _asMap(item), isAvoid: true);

  final Map<String, dynamic> item;
  final bool isAvoid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['name']?.toString() ?? '';
    final weight = double.tryParse('${item['weight'] ?? 0}') ?? 0;
    final evidence =
        (item['evidence'] as List?)?.take(2).map((e) => '《$e》').join(' ') ?? '';

    return Tooltip(
      message: evidence.isEmpty ? name : '$name · $evidence',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isAvoid
              ? cs.errorContainer.withValues(alpha: 0.5)
              : cs.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAvoid)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.block_rounded, size: 13, color: cs.error),
              ),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAvoid ? cs.onErrorContainer : cs.onPrimaryContainer,
              ),
            ),
            if (weight > 0) ...[
              const SizedBox(width: 4),
              Text(
                weight.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  color: isAvoid
                      ? cs.onErrorContainer.withValues(alpha: 0.7)
                      : cs.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HorizontalBarList extends StatelessWidget {
  const _HorizontalBarList({required this.items, required this.color});

  final List<Object?> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maps = items.map(_asMap).toList();
    final maxW = maps.fold<double>(
      0.0,
      (prev, m) => prev > (double.tryParse('${m['weight'] ?? 0}') ?? 0)
          ? prev
          : (double.tryParse('${m['weight'] ?? 0}') ?? 0),
    );

    return Column(
      children: [
        for (final m in maps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    m['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final w = double.tryParse('${m['weight'] ?? 0}') ?? 0;
                      final ratio = maxW > 0 ? w / maxW : 0.0;
                      return Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.02, 1.0),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  child: Text(
                    (double.tryParse('${m['weight'] ?? 0}') ?? 0)
                        .toStringAsFixed(1),
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['name']?.toString() ?? '';
    final weight = double.tryParse('${item['weight'] ?? 0}') ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$name ${weight.toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 12,
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Object?> _asList(Object? v) => v is List ? v : const [];

String _formatTimelineAt(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
