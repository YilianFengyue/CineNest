import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bangumi_info_card.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/source_sheet.dart';
import 'package:cine_nest/pages/feed/detail/widgets/movie_graph_widget.dart';
import 'package:cine_nest/models/movie_graph.dart';
import 'package:cine_nest/http/init.dart';

class KazumiDetailPage extends StatefulWidget {
  const KazumiDetailPage({super.key, required this.item});

  final TmdbMediaItem item;

  @override
  State<KazumiDetailPage> createState() => _KazumiDetailPageState();
}

class _KazumiDetailPageState extends State<KazumiDetailPage>
    with TickerProviderStateMixin {
  static const List<String> _tabs = ['概览', '角色', '制作人员', '图谱'];

  final _favRepo = LocalFavoriteRepository();
  final _tmdb = TmdbDirectService();
  late final TabController _tabController;
  late bool _isFav;

  TmdbCredits? _credits;
  bool _creditsLoading = true;

  String get _favKey => 'tmdb:${widget.item.id}';

  /// 制作人员按职务重要度排序：导演/编剧/原作排前，其余按部门聚拢。
  static List<TmdbCredit> _sortedCrew(List<TmdbCredit> crew) {
    int weight(TmdbCredit c) {
      final job = c.role.toLowerCase();
      if (job.contains('director') && !job.contains('art')) return 0;
      if (job.contains('screenplay') ||
          job.contains('writer') ||
          job.contains('story')) {
        return 1;
      }
      if (job.contains('novel') || job.contains('original')) return 2;
      if (job.contains('producer')) return 3;
      if (job.contains('composer') || job.contains('music')) return 4;
      return 5;
    }

    final sorted = List<TmdbCredit>.from(crew)
      ..sort((a, b) {
        final w = weight(a).compareTo(weight(b));
        return w != 0 ? w : a.department.compareTo(b.department);
      });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _isFav = _favRepo.isFavorite(_favKey);
    _fetchCredits();
  }

  Future<void> _fetchCredits() async {
    try {
      final credits = await _tmdb.credits(
        widget.item.id,
        mediaType: widget.item.mediaType,
      );
      if (mounted) setState(() => _credits = credits);
    } catch (e) {
      debugPrint('>>> [KazumiDetail] credits error: $e');
    } finally {
      if (mounted) setState(() => _creditsLoading = false);
    }
  }

  Future<void> _toggleFav() async {
    await _favRepo.toggle(FavoriteRecord(
      id: '${widget.item.id}',
      title: widget.item.title,
      cover: widget.item.poster(),
      year: widget.item.year,
      source: 'tmdb',
      sourceName: 'TMDB',
      savedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    setState(() => _isFav = !_isFav);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
      ),
      builder: (_) => SourceSheet(
        title: widget.item.title,
        year: widget.item.year,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar.medium(
                title: Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Text(widget.item.title),
                ),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: 0.0,
                leading: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: const [SizedBox(width: 8)],
                stretch: true,
                centerTitle: false,
                expandedHeight: 308 + kTextTabBarHeight + kToolbarHeight,
                collapsedHeight: kTextTabBarHeight +
                    kToolbarHeight +
                    MediaQuery.paddingOf(context).top,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    children: [
                      Positioned.fill(
                        bottom: kTextTabBarHeight,
                        child: IgnorePointer(
                          child: _HeaderBackground(
                            imageUrl: widget.item.poster(),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, kToolbarHeight, 16, 0),
                            child: BangumiInfoCardV(
                              item: widget.item,
                              isFavorite: _isFav,
                              onToggleFavorite: _toggleFav,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerHeight: 0,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(item: widget.item),
            _CreditsTab(
              loading: _creditsLoading,
              entries: _credits?.cast ?? const [],
              isCast: true,
            ),
            _CreditsTab(
              loading: _creditsLoading,
              entries: _sortedCrew(_credits?.crew ?? const []),
              isCast: false,
            ),
            _GraphTab(item: widget.item),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSourceSheet,
        label: const Text('开始观看'),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.item});
  final TmdbMediaItem item;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Builder(
      builder: (context) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('简介', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.overview.isNotEmpty ? widget.item.overview : '暂无简介',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('信息', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '原名: ${widget.item.originalTitle.isNotEmpty ? widget.item.originalTitle : widget.item.title}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '类型: ${widget.item.mediaType == 'tv' ? '剧集' : '电影'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '上映: ${widget.item.releaseDate.isNotEmpty ? widget.item.releaseDate : '未知'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 演职员列表（角色 / 制作人员共用）：Material ListTile 风格，
/// 头像 + 中文名 + 原名副标题，制作人员尾部带职务标签。
class _CreditsTab extends StatelessWidget {
  const _CreditsTab({
    required this.loading,
    required this.entries,
    required this.isCast,
  });

  final bool loading;
  final List<TmdbCredit> entries;
  final bool isCast;

  /// TMDB 的职务名不随 language 本地化，常见职务映射成中文。
  static const Map<String, String> _jobZh = {
    'Director': '导演',
    'Screenplay': '编剧',
    'Writer': '编剧',
    'Story': '故事',
    'Novel': '原作',
    'Original Story': '原作',
    'Comic Book': '原作',
    'Original Concept': '原案',
    'Producer': '制片人',
    'Executive Producer': '监制',
    'Co-Producer': '联合制片',
    'Original Music Composer': '配乐',
    'Music': '音乐',
    'Director of Photography': '摄影',
    'Editor': '剪辑',
    'Production Design': '美术设计',
    'Art Direction': '美术指导',
    'Character Designer': '人物设计',
    'Animation Director': '动画导演',
    'Costume Design': '服装设计',
    'Casting': '选角',
    'Sound Designer': '音效设计',
    'Visual Effects Supervisor': '视效总监',
  };

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _buildTile(context, entries[index]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, TmdbCredit credit) {
    final theme = Theme.of(context);
    final hasOriginalName = credit.originalName.isNotEmpty &&
        credit.originalName != credit.name;
    final subtitle = isCast
        ? (credit.role.isNotEmpty ? '饰 ${credit.role}' : '')
        : (hasOriginalName ? credit.originalName : '');
    final trailing = isCast
        ? (hasOriginalName ? credit.originalName : '')
        : (_jobZh[credit.role] ?? credit.role);

    return ListTile(
      leading: credit.profilePath.isNotEmpty
          ? NetworkImgLayer(
              src: credit.profile(),
              width: 48,
              height: 48,
              type: 'avatar',
            )
          : CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      title: Text(
        credit.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing.isEmpty
          ? null
          : Text(
              trailing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _GraphTab extends StatefulWidget {
  const _GraphTab({required this.item});
  final TmdbMediaItem item;

  @override
  State<_GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<_GraphTab>
    with AutomaticKeepAliveClientMixin {
  MovieGraphResponse? _graph;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response =
          await Request().get('/api/movie/${widget.item.id}/graph');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('nodes')) {
          if (mounted) setState(() => _graph = MovieGraphResponse.fromJson(data));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败');
      debugPrint('>>> [GraphTab] Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Builder(
      builder: (context) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle:
                  NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || _graph == null || _graph!.nodes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded,
                          size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? '暂无图谱数据',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  child: MovieGraphWidget(graph: _graph!),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.imageUrl});

  static const double _downsample = 0.5;
  static const double _blurSigma = 15.0;
  static const double _opacity = 0.4;
  static const double _edgeBleed = 32.0;
  static const double _bottomFeatherHeight = 48.0;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.shrink();

        final rasterWidth = width * _downsample;
        final rasterHeight = (height + _edgeBleed) * _downsample;
        final bgColor = Theme.of(context).scaffoldBackgroundColor;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.8, 1],
                ).createShader(bounds),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    child: Transform.scale(
                      scale: 1 / _downsample,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                      child: SizedBox(
                        width: rasterWidth,
                        height: rasterHeight,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurSigma * _downsample,
                            sigmaY: _blurSigma * _downsample,
                          ),
                          child: NetworkImgLayer(
                            src: imageUrl,
                            width: rasterWidth,
                            height: rasterHeight,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            filterQuality: FilterQuality.low,
                            color: Colors.white.withValues(alpha: _opacity),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _bottomFeatherHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor.withValues(alpha: 0),
                        bgColor.withValues(alpha: 0.55),
                        bgColor,
                      ],
                      stops: const [0, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
