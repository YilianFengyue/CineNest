import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadData(),
          child: CustomScrollView(
            slivers: [
              // 1. 沉浸式大标题：取代原有的两个 AppBar 文本
              SliverAppBar(
                expandedHeight: 100.0,
                floating: true,
                pinned: false, // 随滑动消失，让位给内容
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
              // 2. 帖子列表
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