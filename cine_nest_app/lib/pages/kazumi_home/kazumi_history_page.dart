import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cine_nest/repositories/local_history_repository.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/source_sheet.dart';

class KazumiHistoryPage extends StatefulWidget {
  const KazumiHistoryPage({super.key});

  @override
  State<KazumiHistoryPage> createState() => _KazumiHistoryPageState();
}

class _KazumiHistoryPageState extends State<KazumiHistoryPage> {
  final _repo = LocalHistoryRepository();
  final _favRepo = LocalFavoriteRepository();
  late List<HistoryRecord> _records;
  bool _editMode = false;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _records = _repo.loadAll();
  }

  void _refresh() => setState(() {
        _records = _repo.loadAll();
        _selected.clear();
      });

  Future<void> _deleteSelected() async {
    for (final key in _selected) {
      await _repo.remove(key);
    }
    _refresh();
    setState(() => _editMode = false);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定清空所有观看记录？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.clear();
      _refresh();
      setState(() => _editMode = false);
    }
  }

  void _openSourceSheet(HistoryRecord record) {
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

  String _timeAgo(int ms) {
    final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${diff.inDays ~/ 30}个月前';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          if (_records.isNotEmpty) ...[
            IconButton(
              icon: Icon(_editMode ? Icons.close : Icons.edit_outlined),
              tooltip: _editMode ? '退出编辑' : '编辑',
              onPressed: () => setState(() {
                _editMode = !_editMode;
                _selected.clear();
              }),
            ),
            if (_editMode)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: '清空全部',
                onPressed: _clearAll,
              )
            else
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '清空',
                onPressed: _clearAll,
              ),
          ],
        ],
      ),
      bottomNavigationBar: _editMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('删除 ${_selected.length} 项'),
                ),
              ),
            )
          : null,
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('暂无观看记录',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, i) {
                final record = _records[i];
                final isFav = _favRepo.isFavorite(record.key);
                return _HistoryCard(
                  record: record,
                  isFavorite: isFav,
                  editMode: _editMode,
                  isSelected: _selected.contains(record.key),
                  timeAgo: _timeAgo(record.savedAt),
                  onTap: () {
                    if (_editMode) {
                      setState(() {
                        if (_selected.contains(record.key)) {
                          _selected.remove(record.key);
                        } else {
                          _selected.add(record.key);
                        }
                      });
                    } else {
                      _openSourceSheet(record);
                    }
                  },
                  onFavToggle: () async {
                    await _favRepo.toggle(FavoriteRecord(
                      id: record.id,
                      title: record.title,
                      cover: record.cover,
                      year: record.year,
                      source: record.source,
                      sourceName: record.sourceName,
                      savedAt: DateTime.now().millisecondsSinceEpoch,
                    ));
                    setState(() {});
                  },
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.isFavorite,
    required this.editMode,
    required this.isSelected,
    required this.timeAgo,
    required this.onTap,
    required this.onFavToggle,
  });

  final HistoryRecord record;
  final bool isFavorite;
  final bool editMode;
  final bool isSelected;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onFavToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 编辑模式 checkbox ──
            if (editMode)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 20),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),

            // ── 封面 ──
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 120,
                child: record.cover != null
                    ? CachedNetworkImage(
                        imageUrl: record.cover!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _CoverPlaceholder(cs: cs),
                      )
                    : _CoverPlaceholder(cs: cs),
              ),
            ),
            const SizedBox(width: 12),

            // ── 信息 ──
            Expanded(
              child: SizedBox(
                height: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          record.episodeName ?? '第${record.episodeIndex + 1}集',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star_border,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          record.sourceName,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 右侧按钮 ──
            if (!editMode)
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? cs.primary : cs.onSurfaceVariant,
                    ),
                    onPressed: onFavToggle,
                  ),
                  IconButton(
                    icon: Icon(Icons.open_in_new,
                        color: cs.onSurfaceVariant),
                    onPressed: onTap,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 28),
      ),
    );
  }
}
