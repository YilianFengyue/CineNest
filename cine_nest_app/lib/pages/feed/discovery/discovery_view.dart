import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'discovery_controller.dart';
import '../feed_controller.dart';

class DiscoveryPage extends GetView<DiscoveryController> {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(DiscoveryController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value && controller.movieList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadData(),
          child: CustomScrollView(
            slivers: [
              // 1. 顶部横幅：专属推荐 & 观影历史
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                  child: Row(
                    children: [
                      // 左侧：专属推荐
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (Get.isRegistered<FeedController>()) {
                              Get.delete<FeedController>(force: true);
                            }
                            Get.toNamed('/feed');
                          },
                          child: _buildBannerCard(
                            context,
                            title: "专属推荐",
                            subtitle: "AI 解析画像",
                            icon: Icons.psychology_outlined,
                            colors: [colorScheme.primary, colorScheme.tertiary],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 右侧：观影历史
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Get.toNamed(Routes.history),
                          child: _buildBannerCard(
                            context,
                            title: "观影历史",
                            subtitle: "足迹回顾",
                            icon: Icons.history_rounded,
                            colors: [Colors.orange, Colors.deepOrangeAccent],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. 标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    "全球热门探索",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 3. 热门电影网格：调整为一行 3 个
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 一行展示 3 个
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.58, // 由于宽度变窄，需要调整宽高比以适应封面和文字
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final movie = controller.movieList[index];
                    String imageUrl = movie.posterUrl ?? '';
                    if (imageUrl.startsWith('/api')) {
                      imageUrl = '${Request.dio.options.baseUrl}$imageUrl';
                    }

                    return RepaintBoundary(
                      child: GestureDetector(
                        onTap: () => Get.toNamed(
                          Routes.movieDetail,
                          arguments: {'movieId': movie.id},
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 180,
                                  placeholder: (context, url) => Container(
                                    color: colorScheme.surfaceContainerHighest,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.movie, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "${movie.rating ?? 0.0}",
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: controller.movieList.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBannerCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 60, color: Colors.white.withAlpha(30)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
