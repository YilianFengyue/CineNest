import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'feed_controller.dart';
import 'widgets/post_card.dart';

class FeedPage extends GetView<FeedController> {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 注入 Controller
    Get.put(FeedController());

    return Scaffold(
      body: Obx(() {
        return RefreshIndicator(
          onRefresh: () => controller.loadData(),
          child: CustomScrollView(
            slivers: [
              // 1. 沉浸式大标题
              SliverAppBar(
                expandedHeight: 100.0,
                floating: true,
                pinned: false,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    "为你精选",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                ),
              ),

              // 2. 场景推荐引导入口
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: InkWell(
                    onTap: () => Get.toNamed(Routes.scenario),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.surfaceVariant,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "试试按心情找片？",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "输入“想看点甜的”或“想看爽片”试试",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. 帖子列表
              if (controller.isLoading.value)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return PostCard(post: controller.postList[index]);
                    },
                    childCount: controller.postList.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
      }),
    );
  }
}
