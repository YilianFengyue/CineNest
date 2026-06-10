import 'package:cine_nest/pages/creative/favorites_controller.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/utils/placeholder_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 我的收藏页（成员 C）—— 资讯 / 海报通用收藏的统一展示。
///
/// 数据来自 [FavoritesController]（本地 Hive）。点海报类收藏 → 直接回到那张互动海报；
/// 资讯类暂以 mock 海报占位（Step 3 接真资讯详情后再深链）。
/// 设计：Material You tonal 卡片、零阴影、紧凑。
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fav = FavoritesController.to;
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: Obx(() {
        // 读 ids 让增删即时刷新。
        fav.ids.length;
        final list = fav.entries();
        if (list.isEmpty) return const _EmptyFav();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _FavTile(data: list[i]),
        );
      }),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({required this.data});

  final Map<String, dynamic> data;

  void _open() {
    final id = data['id'] as String? ?? '';
    // 'poster:<provider>:<source>' → 深链真海报；其余走 mock 海报。
    if (id.startsWith('poster:')) {
      final parts = id.split(':');
      if (parts.length >= 3) {
        Get.toNamed(Routes.creativePoster, arguments: {
          'catalog_provider_id': parts[1],
          'catalog_source_id': parts[2],
          'media_kind': 'movie',
        });
        return;
      }
    }
    Get.toNamed(Routes.creativePoster);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = data['title'] as String? ?? '未命名';
    final cover = data['cover'] as String? ?? '';
    final type = data['type'] as String? ?? 'news';
    final id = data['id'] as String? ?? '';
    final isPoster = type == 'poster';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CoverImage(
                  url: cover,
                  seed: title,
                  width: 64,
                  height: 84,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPoster ? '互动海报' : '资讯',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '取消收藏',
                icon: Icon(Icons.favorite, color: cs.error),
                onPressed: () => FavoritesController.to.toggle(id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFav extends StatelessWidget {
  const _EmptyFav();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 44, color: cs.outline),
          const SizedBox(height: 12),
          Text(
            '还没有收藏\n在资讯卡或海报页点 ♥ 收藏',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}
