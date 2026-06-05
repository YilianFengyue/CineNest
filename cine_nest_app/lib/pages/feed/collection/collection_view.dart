import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'collection_controller.dart';
import 'package:cine_nest/http/init.dart';

class CollectionPage extends GetView<CollectionController> {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CollectionController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.collectionList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                const Text('暂无收藏电影'),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: controller.collectionList.length,
          itemBuilder: (context, index) {
            final item = controller.collectionList[index];
            String imageUrl = item['poster_url'] ?? '';
            if (imageUrl.startsWith('/api')) {
              imageUrl = '${Request.dio.options.baseUrl}$imageUrl';
            }

            return GestureDetector(
              onTap: () => Get.toNamed(
                Routes.movieDetail,
                arguments: {'movieId': item['movie_id']},
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
                    item['title'] ?? '未知电影',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
