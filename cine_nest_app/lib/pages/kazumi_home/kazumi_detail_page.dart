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
  static const List<String> _tabs = ['概览', '吐槽', '角色', '评论', '制作人员'];

  final _favRepo = LocalFavoriteRepository();
  late final TabController _tabController;
  late bool _isFav;

  String get _favKey => 'tmdb:${widget.item.id}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _isFav = _favRepo.isFavorite(_favKey);
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
            _PlaceholderTab(label: '吐槽'),
            _PlaceholderTab(label: '角色'),
            _PlaceholderTab(label: '评论'),
            _PlaceholderTab(label: '制作人员'),
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
  MovieGraphResponse? _graph;
  bool _isLoadingGraph = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint(">>> [_OverviewTab] initState for movie ${widget.item.id}");
    _fetchGraph();
  }

  Future<void> _fetchGraph() async {
    try {
      setState(() => _isLoadingGraph = true);
      debugPrint(">>> [KazumiGraph] Fetching graph for movie ${widget.item.id}...");
      final response = await Request().get("/api/movie/${widget.item.id}/graph");
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('nodes')) {
          setState(() {
            _graph = MovieGraphResponse.fromJson(data);
          });
          debugPrint(">>> [KazumiGraph] Success: ${_graph?.nodes.length} nodes");
        }
      }
    } catch (e) {
      debugPrint(">>> [KazumiGraph] Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingGraph = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 这是 AutomaticKeepAliveClientMixin 的要求
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
                  const SizedBox(height: 32),
                  
                  // 关系图谱部分
                  StatefulBuilder(
                    builder: (context, setTabState) {
                      if (_isLoadingGraph) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (_graph != null) {
                        return MovieGraphWidget(graph: _graph!);
                      }
                      return const SizedBox.shrink();
                    },
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '$label - 开发中',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
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
