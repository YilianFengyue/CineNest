import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/source_manager_controller.dart';
import '../widgets/source_health_chip.dart';

class SourceManagerTemplePage extends StatelessWidget {
  const SourceManagerTemplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(SourceManagerController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('源管理 Temple'),
        actions: [
          IconButton(
            tooltip: '清空健康记录',
            onPressed: ctrl.clearHealth,
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
          IconButton(
            tooltip: '恢复默认源',
            onPressed: ctrl.resetSources,
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.sources.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          itemCount: ctrl.sources.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final source = ctrl.sources[index];
            final health = ctrl.health[source.key];
            return SwitchListTile(
              value: source.enabled,
              onChanged: (value) => ctrl.setEnabled(source, value),
              secondary: SourceHealthChip(health: health),
              title: Text(source.name),
              subtitle: Text(
                source.api,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      }),
    );
  }
}
