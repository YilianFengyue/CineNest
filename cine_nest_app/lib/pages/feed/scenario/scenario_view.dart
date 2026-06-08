import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'scenario_controller.dart';
import '../widgets/post_card.dart';

class ScenarioPage extends GetView<ScenarioController> {
  const ScenarioPage({super.key});

  static const List<String> suggestions = [
    "想看点甜的",
    "适合下饭的电影",
    "今晚想大哭一场",
    "刺激的科幻大片",
    "深度反转悬疑",
    "想看高分经典",
    "适合深夜emo看",
    "热血沸腾的运动片",
  ];

  @override
  Widget build(BuildContext context) {
    Get.put(ScenarioController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("心情/场景找片"),
        centerTitle: true,
      ),
      body: Obx(() {
        return CustomScrollView(
          slivers: [
            // 1. 输入框与快捷标签 (常驻顶部)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller.inputController,
                            decoration: InputDecoration(
                              hintText: "输入你现在的心情或场景...",
                              prefixIcon: const Icon(Icons.psychology),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: (val) => controller.fetchRecommendations(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => controller.fetchRecommendations(controller.inputController.text),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                          child: const Text("发现"),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(s),
                          onPressed: () => controller.onScenarioSelected(s),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 2. 调试信息 (如果有)
            if (controller.debugInfo.value != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.debugInfo.value!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. 加载中或空状态
            if (controller.isLoading.value)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.postList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_filter_outlined, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text("输入点什么，开启专属推荐吧", style: TextStyle(color: theme.disabledColor)),
                    ],
                  ),
                ),
              )
            else
            // 4. 核心列表 (使用 SliverList)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return PostCard(post: controller.postList[index]);
                  },
                  childCount: controller.postList.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      }),
    );
  }
}
