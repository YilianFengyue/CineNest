import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'history_controller.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(HistoryController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('观影历史'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.historyList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text('暂无观影历史'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.historyList.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = controller.historyList[index];
            return ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: Text(
                item['title'] ?? '未知电影',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('访问时间: ${item['visited_at'] ?? '未知'}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Get.toNamed(
                  Routes.movieDetail,
                  arguments: {'movieId': item['movie_id']},
                );
              },
            );
          },
        );
      }),
    );
  }
}
