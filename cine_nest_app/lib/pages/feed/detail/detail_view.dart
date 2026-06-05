import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_controller.dart';

class MovieDetailPage extends GetView<MovieDetailController> {
  const MovieDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 注入 Controller
    Get.put(MovieDetailController());

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final movie = controller.movie.value;
        if (movie == null) {
          return const Center(child: Text("未找到电影详情"));
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        // 处理背景和海报 URL
        String backdropUrl = movie.backdropUrl ?? '';
        if (backdropUrl.startsWith('/api')) {
          backdropUrl = '${Request.dio.options.baseUrl}$backdropUrl';
        }

        String posterUrl = movie.posterUrl ?? '';
        if (posterUrl.startsWith('/api')) {
          posterUrl = '${Request.dio.options.baseUrl}$posterUrl';
        }

        return CustomScrollView(
          slivers: [
            // 1. 沉浸式海报背景
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              actions: [
                Obx(() => IconButton(
                  onPressed: () => controller.toggleFavorite(),
                  icon: Icon(
                    controller.isFavorited.value ? Icons.favorite : Icons.favorite_border,
                    color: controller.isFavorited.value ? Colors.red : Colors.white,
                  ),
                )),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Container(color: colorScheme.surfaceContainerHighest),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. 电影核心信息
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧小海报
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: posterUrl,
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // 右侧基本信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${movie.year ?? ''} · ${movie.genres.join(' / ')}",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${movie.rating ?? 0.0}",
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "/ 10 (TMDB)",
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 3. 剧情简介
                    Text(
                      "剧情简介",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      movie.overview ?? "暂无简介",
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),

                    const SizedBox(height: 24),

                    // 4. 演职员 (简单列表)
                    if (movie.directors.isNotEmpty) ...[
                      Text(
                        "导演",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(movie.directors.join(", ")),
                      const SizedBox(height: 16),
                    ],

                    if (movie.cast.isNotEmpty) ...[
                      Text(
                        "主演",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(movie.cast.join(", ")),
                    ],

                    const SizedBox(height: 100), // 底部留白
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      // 悬浮播放按钮（F3 任务预留）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final movie = controller.movie.value;
          if (movie == null) {
            return;
          }
          Get.toNamed(Routes.sourcePicker, arguments: {'title': movie.title});
        },
        label: const Text("立即播放"),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}
