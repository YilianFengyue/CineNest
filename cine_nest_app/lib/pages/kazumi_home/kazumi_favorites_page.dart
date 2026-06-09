import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/source_sheet.dart';

class KazumiFavoritesPage extends StatefulWidget {
  const KazumiFavoritesPage({super.key});

  @override
  State<KazumiFavoritesPage> createState() => _KazumiFavoritesPageState();
}

class _KazumiFavoritesPageState extends State<KazumiFavoritesPage> {
  final _repo = LocalFavoriteRepository();
  late List<FavoriteRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = _repo.loadAll();
  }

  void _refresh() => setState(() => _records = _repo.loadAll());

  Future<void> _remove(FavoriteRecord record) async {
    await _repo.remove(record.key);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('暂无收藏', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.55,
              ),
              itemCount: _records.length,
              itemBuilder: (context, i) => _FavCard(
                record: _records[i],
                onRemove: () => _remove(_records[i]),
              ),
            ),
    );
  }
}

class _FavCard extends StatelessWidget {
  const _FavCard({required this.record, required this.onRemove});

  final FavoriteRecord record;
  final VoidCallback onRemove;

  void _openSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
      ),
      builder: (_) => SourceSheet(title: record.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openSourceSheet(context),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('取消收藏'),
              content: Text('确定取消收藏「${record.title}」？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
              ],
            ),
          );
          if (ok == true) onRemove();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: record.cover != null
                  ? CachedNetworkImage(
                      imageUrl: record.cover!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                    )
                  : ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.movie, color: cs.onSurfaceVariant),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Text(
                record.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Text(
                '${record.sourceName} · ${record.episodeCount}集',
                maxLines: 1,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
