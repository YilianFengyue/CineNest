import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/utils/media_url.dart';
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
              // 1. 顶部操作区：专属推荐 & 观影历史 & 我的收藏
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 8),
                  child: Column(
                    children: [
                      // 第一行：专属推荐（大横幅）
                      GestureDetector(
                        onTap: () {
                          if (Get.isRegistered<FeedController>()) {
                            Get.delete<FeedController>(force: true);
                          }
                          Get.toNamed('/feed');
                        },
                        child: _buildLargeBanner(
                          context,
                          title: "专属智能推荐",
                          subtitle: "基于 AI 解析你的灵魂画像",
                          icon: Icons.auto_awesome,
                          colors: [colorScheme.primary, colorScheme.tertiary],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 第二行：并列的两个小按钮
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Get.toNamed(Routes.history),
                              child: _buildSmallBanner(
                                context,
                                title: "观影历史",
                                icon: Icons.history_rounded,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Get.toNamed(Routes.collection),
                              child: _buildSmallBanner(
                                context,
                                title: "我的收藏",
                                icon: Icons.favorite_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. 标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final movie = controller.movieList[index];
                      final imageUrl = mediaUrl(movie.posterUrl ?? '');

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
                    },
                    childCount: controller.movieList.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLargeBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      height: 100,
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
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon, size: 100, color: Colors.white.withAlpha(30)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.psychology_outlined, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBanner(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: color.withAlpha(230),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
