import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../router/app_pages.dart';
import '../controllers/aggregator_test_controller.dart';
import '../models/media_models.dart';
import '../widgets/aggregator_media_card.dart';

class AggregatorTemplePage extends StatefulWidget {
  const AggregatorTemplePage({super.key});

  @override
  State<AggregatorTemplePage> createState() => _AggregatorTemplePageState();
}

class _AggregatorTemplePageState extends State<AggregatorTemplePage> {
  final _searchCtrl = TextEditingController(text: '庆余年');
  late final AggregatorTestController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(AggregatorTestController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<AggregatorTestController>();
    super.dispose();
  }

  void _submit() => _ctrl.search(_searchCtrl.text);

  void _openDetail(AggregatorSearchResult item) {
    Get.toNamed(Routes.aggregatorDetailTemple, arguments: item);
  }

  void _quickPlay(AggregatorSearchResult item) {
    Get.toNamed(Routes.aggregatorDetailTemple, arguments: item);
  }

  void _showTrace() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Obx(() {
          final traces = _ctrl.traces;
          if (traces.isEmpty) {
            return const Center(child: Text('暂无 trace'));
          }
          return ListView.separated(
            itemCount: traces.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final trace = traces[index];
              return ListTile(
                leading: Icon(
                  trace.ok ? Icons.check_circle : Icons.error_outline,
                  color: trace.ok ? Colors.green : Colors.red,
                ),
                title: Text(trace.sourceName),
                subtitle: Text(
                  trace.ok
                      ? '${trace.resultCount} 条 · ${trace.elapsedMs}ms'
                      : trace.error ?? '失败',
                ),
                trailing: Text(trace.source),
              );
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('聚合器 Temple'),
        actions: [
          IconButton(
            tooltip: '源管理',
            onPressed: () => Get.toNamed(Routes.sourceManagerTemple),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Trace',
            onPressed: _showTrace,
            icon: const Icon(Icons.terminal),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: '搜索影片 / 剧集',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('搜索'),
                ),
              ],
            ),
          ),
          Obx(() => _StatusBar(ctrl: _ctrl)),
          Expanded(
            child: Obx(() {
              final results = _ctrl.results;
              if (_ctrl.searching.value && results.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (results.isEmpty) {
                return Center(
                  child: Text('输入片名开始聚合搜索', style: theme.textTheme.bodyMedium),
                );
              }
              return ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = results[index];
                  return AggregatorMediaCard(
                    item: item,
                    onDetail: () => _openDetail(item),
                    onPlay: () => _quickPlay(item),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.ctrl});

  final AggregatorTestController ctrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = ctrl.totalSources.value;
    final completed = ctrl.completedSources.value;
    final searching = ctrl.searching.value;
    final text = total == 0
        ? (searching ? '准备搜索' : '空闲')
        : '${searching ? '搜索中' : '已完成'} $completed/$total · ${ctrl.results.length} 条';
    return Column(
      children: [
        LinearProgressIndicator(
          value: total == 0 ? null : ctrl.progress.clamp(0, 1),
          minHeight: 2,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          child: Row(
            children: [
              Icon(
                searching ? Icons.sync : Icons.done,
                size: 16,
                color: searching ? cs.primary : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
              if (ctrl.fromCache.value)
                Text('缓存先行', style: TextStyle(color: cs.primary)),
              if (searching)
                TextButton(onPressed: ctrl.stopSearch, child: const Text('停止')),
            ],
          ),
        ),
      ],
    );
  }
}
