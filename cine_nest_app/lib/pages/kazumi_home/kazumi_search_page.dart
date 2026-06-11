import 'package:flutter/material.dart';

import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_detail_page.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bangumi_card_v.dart';
import 'package:cine_nest/utils/storage.dart';
import 'package:cine_nest/utils/storage_key.dart';

class KazumiSearchPage extends StatefulWidget {
  const KazumiSearchPage({super.key});

  @override
  State<KazumiSearchPage> createState() => _KazumiSearchPageState();
}

class _KazumiSearchPageState extends State<KazumiSearchPage> {
  final _tmdb = TmdbDirectService();
  final _searchCtrl = SearchController();
  final _scrollCtrl = ScrollController();
  final _results = <TmdbMediaItem>[];
  bool _loading = false;
  bool _timeout = false;
  String _sortBy = 'match';
  bool _onlyMovie = false;
  bool _onlyTv = false;

  List<String> _history = [];
  static const int _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_scrollListener);
    _loadHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── 搜索历史 ──

  void _loadHistory() {
    final raw = GStorage.localCache.get(LocalCacheKey.searchHistory);
    if (raw is List) {
      _history = raw.cast<String>();
    }
  }

  Future<void> _saveHistory() =>
      GStorage.localCache.put(LocalCacheKey.searchHistory, _history);

  void _addToHistory(String term) {
    _history.remove(term);
    _history.insert(0, term);
    if (_history.length > _maxHistory) {
      _history = _history.sublist(0, _maxHistory);
    }
    _saveHistory();
  }

  void _removeFromHistory(String term) {
    setState(() => _history.remove(term));
    _saveHistory();
  }

  void _clearHistory() {
    setState(() => _history.clear());
    _saveHistory();
  }

  // ── 搜索逻辑 ──

  void _scrollListener() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loading &&
        _results.isNotEmpty) {
      _loadMore();
    }
  }

  int _page = 1;

  Future<void> _search(String query, {bool append = false}) async {
    if (query.trim().isEmpty) return;
    if (!append) {
      _addToHistory(query.trim());
      setState(() {
        _loading = true;
        _timeout = false;
        _page = 1;
        _results.clear();
      });
    }
    try {
      final futures = <Future<List<TmdbMediaItem>>>[];
      if (!_onlyTv) {
        futures.add(_tmdb.search(query, mediaType: 'movie', page: _page));
      }
      if (!_onlyMovie) {
        futures.add(_tmdb.search(query, mediaType: 'tv', page: _page));
      }
      final lists = await Future.wait(futures);
      final merged = lists.expand((l) => l).toList();
      _sortResults(merged);
      setState(() {
        _results.addAll(merged);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _timeout = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _search(_searchCtrl.text, append: true);
  }

  void _sortResults(List<TmdbMediaItem> items) {
    switch (_sortBy) {
      case 'rating':
        items.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        break;
      case 'popularity':
        items.sort((a, b) => b.voteCount.compareTo(a.voteCount));
        break;
      default:
        break;
    }
  }

  void _showSearchSettings() {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.35,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => _SearchSettingsSheet(
        sortBy: _sortBy,
        onlyMovie: _onlyMovie,
        onlyTv: _onlyTv,
        onApply: (sort, movie, tv) {
          Navigator.pop(ctx);
          setState(() {
            _sortBy = sort;
            _onlyMovie = movie;
            _onlyTv = tv;
          });
          if (_searchCtrl.text.isNotEmpty) {
            _search(_searchCtrl.text);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('搜索'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSearchSettings,
        icon: const Icon(Icons.sort),
        label: const Text('搜索设置'),
      ),
      body: Column(
        children: [
          // ── 搜索栏 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: '搜索电影、剧集...',
              elevation: WidgetStateProperty.all(0),
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _results.clear();
                        _timeout = false;
                      });
                    },
                  ),
              ],
              onSubmitted: (v) => _search(v),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ── 内容 ──
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_timeout && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('什么都没有找到 (´;ω;`)'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _search(_searchCtrl.text),
              child: const Text('点击重试'),
            ),
          ],
        ),
      );
    }

    // 无查询 or 清空后 → 显示搜索历史
    if (_results.isEmpty && _searchCtrl.text.isEmpty) {
      return _buildHistory(cs);
    }

    if (_results.isEmpty) {
      return Center(
        child: Text('未找到结果', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    int crossCount = 3;
    if (width > 600) crossCount = 5;
    if (width > 840) crossCount = 6;

    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 8,
        mainAxisExtent: width / crossCount / 0.65 +
            MediaQuery.textScalerOf(context).scale(32.0),
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        return BangumiCardV(
          item: item,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => KazumiDetailPage(item: item)),
          ),
        );
      },
    );
  }

  Widget _buildHistory(ColorScheme cs) {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索 TMDB',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      itemCount: _history.length + 1,
      itemBuilder: (context, i) {
        // 头部：标题 + 清空按钮
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Text(
                  '搜索历史',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('清空'),
                ),
              ],
            ),
          );
        }

        final term = _history[i - 1];
        return ListTile(
          leading: Icon(Icons.history, color: cs.onSurfaceVariant, size: 20),
          title: Text(term),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            onPressed: () => _removeFromHistory(term),
          ),
          onTap: () {
            _searchCtrl.text = term;
            _search(term);
          },
        );
      },
    );
  }
}

// ── 搜索设置 Sheet ──
class _SearchSettingsSheet extends StatefulWidget {
  const _SearchSettingsSheet({
    required this.sortBy,
    required this.onlyMovie,
    required this.onlyTv,
    required this.onApply,
  });

  final String sortBy;
  final bool onlyMovie;
  final bool onlyTv;
  final void Function(String sort, bool movie, bool tv) onApply;

  @override
  State<_SearchSettingsSheet> createState() => _SearchSettingsSheetState();
}

class _SearchSettingsSheetState extends State<_SearchSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late String _sortBy;
  late bool _onlyMovie;
  late bool _onlyTv;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _sortBy = widget.sortBy;
    _onlyMovie = widget.onlyMovie;
    _onlyTv = widget.onlyTv;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: '排序方式'), Tab(text: '过滤器')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── 排序 ──
              ListView(
                children: [
                  _sortTile('按匹配程度排序', 'match'),
                  _sortTile('按热度排序', 'popularity'),
                  _sortTile('按评分排序', 'rating'),
                ],
              ),
              // ── 过滤 ──
              ListView(
                children: [
                  SwitchListTile(
                    title: const Text('仅显示电影'),
                    value: _onlyMovie,
                    onChanged: (v) => setState(() {
                      _onlyMovie = v;
                      if (v) _onlyTv = false;
                      widget.onApply(_sortBy, _onlyMovie, _onlyTv);
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('仅显示剧集'),
                    value: _onlyTv,
                    onChanged: (v) => setState(() {
                      _onlyTv = v;
                      if (v) _onlyMovie = false;
                      widget.onApply(_sortBy, _onlyMovie, _onlyTv);
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sortTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: _sortBy == value
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        setState(() => _sortBy = value);
        widget.onApply(_sortBy, _onlyMovie, _onlyTv);
      },
    );
  }
}
