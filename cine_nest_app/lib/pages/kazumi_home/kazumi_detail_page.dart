import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cine_nest/pages/kazumi_home/mock_data.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bangumi_info_card.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/network_img_layer.dart';

class KazumiDetailPage extends StatefulWidget {
  const KazumiDetailPage({super.key, required this.bangumiItem});

  final MockBangumiItem bangumiItem;

  @override
  State<KazumiDetailPage> createState() => _KazumiDetailPageState();
}

class _KazumiDetailPageState extends State<KazumiDetailPage>
    with TickerProviderStateMixin {
  static const List<String> _tabs = ['概览', '吐槽', '角色', '评论', '制作人员'];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  child: Text(
                    widget.bangumiItem.nameCn.isNotEmpty
                        ? widget.bangumiItem.nameCn
                        : widget.bangumiItem.name,
                  ),
                ),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: 0.0,
                leading: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_browser_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
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
                            imageUrl: widget.bangumiItem.imageUrl,
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
                              bangumiItem: widget.bangumiItem,
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
            _OverviewTab(bangumiItem: widget.bangumiItem),
            _PlaceholderTab(label: '吐槽'),
            _PlaceholderTab(label: '角色'),
            _PlaceholderTab(label: '评论'),
            _PlaceholderTab(label: '制作人员'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('开始观看'),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}

// ── 概览 Tab ──
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.bangumiItem});
  final MockBangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
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
                    bangumiItem.summary.isNotEmpty
                        ? bangumiItem.summary
                        : '暂无简介',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('标签', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['奇幻', '冒险', '热血', '原创']
                        .map((tag) => ActionChip(
                              label: Text(tag),
                              onPressed: () {},
                            ))
                        .toList(),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 占位 Tab ──
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

// ── 详情页头部背景（高斯模糊封面）──
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
