import 'package:cine_nest/services/agent_memory_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class AgentProfilePage extends StatefulWidget {
  const AgentProfilePage({super.key});

  @override
  State<AgentProfilePage> createState() => _AgentProfilePageState();
}

class _AgentProfilePageState extends State<AgentProfilePage> {
  final _service = AgentMemoryService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchProfile();
  }

  Future<void> _sync() async {
    SmartDialog.showLoading(msg: '正在同步本地画像');
    try {
      await _service.syncLocalSignals();
      final profile = await _service.fetchProfile();
      if (!mounted) return;
      setState(() => _future = Future.value(profile));
      SmartDialog.showToast('画像已同步');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _rebuild() async {
    SmartDialog.showLoading(msg: '正在重建画像');
    try {
      final profile = await _service.rebuildProfile();
      if (!mounted) return;
      setState(() => _future = Future.value(profile));
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
            tooltip: '同步',
            onPressed: _sync,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: '重建',
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
          return _ProfileBody(data: data);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tags = (data['taste_tags'] as List? ?? const []);
    final sources = (data['source_distribution'] as List? ?? const []);
    final metrics = (data['radar_metrics'] as List? ?? const []);
    final timeline = (data['timeline'] as List? ?? const []);
    final stats = Map<String, dynamic>.from(
      (data['stats'] as Map?) ?? const {},
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          data['summary']?.toString() ?? '暂无画像',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: '记忆', value: stats['memory_count']),
            _StatChip(label: '历史', value: stats['history_count']),
            _StatChip(label: '收藏', value: stats['favorite_count']),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle('偏好标签'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in tags)
              Chip(
                label: Text(
                  Map<String, dynamic>.from(item as Map)['name'].toString(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle('雷达指标'),
        for (final item in metrics)
          _MetricBar(item: Map<String, dynamic>.from(item as Map)),
        const SizedBox(height: 20),
        _SectionTitle('片源分布'),
        for (final item in sources)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.hub_outlined, color: cs.primary),
            title: Text(
              Map<String, dynamic>.from(item as Map)['name'].toString(),
            ),
            trailing: Text('${Map<String, dynamic>.from(item)['weight'] ?? 0}'),
          ),
        const SizedBox(height: 20),
        _SectionTitle('最近记忆'),
        for (final item in timeline.take(12))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timeline_rounded),
            title: Text(
              Map<String, dynamic>.from(item as Map)['title'].toString(),
            ),
            subtitle: Text(
              Map<String, dynamic>.from(item)['subtitle']?.toString() ?? '',
            ),
          ),
      ],
    );
  }
}

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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label ${value ?? 0}'));
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse('${item['value'] ?? 0}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item['label']?.toString() ?? '指标')),
              Text(value.toStringAsFixed(0)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: (value / 100).clamp(0, 1)),
        ],
      ),
    );
  }
}
