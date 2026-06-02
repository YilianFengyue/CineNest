import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'discovery_controller.dart';

class DiscoveryPage extends GetView<DiscoveryController> {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(DiscoveryController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadData(),
          child: CustomScrollView(
            slivers: [
              // 1. 顶部横幅：专属推荐入口
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Get.toNamed('/feed'), // 跳转到之前的 AI 推荐页
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(50),
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
                          child: Icon(Icons.auto_awesome, size: 100, color: Colors.white.withAlpha(30)),
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
                                    const Text(
                                      "专属智能推荐",
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "基于 AI 解析你的灵魂画像",
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
                  ),
                ),
              ),

              // 2. 标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    "全球热门探索",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final movie = controller.movieList[index];
                      String imageUrl = movie.posterUrl ?? '';
                      if (imageUrl.startsWith('/api')) {
                        imageUrl = '${Request().dio.options.baseUrl}$imageUrl';
                      }
                      
                      return GestureDetector(
                        onTap: () => Get.toNamed(Routes.movieDetail, arguments: {'movieId': movie.id}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
                                  errorWidget: (context, url, error) => const Icon(Icons.movie, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  "${movie.rating ?? 0.0}",
                                  style: TextStyle(color: colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
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
}
