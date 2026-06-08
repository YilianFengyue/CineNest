import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cine_nest/pages/kazumi_home/mock_data.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bangumi_card_v.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_detail_page.dart';

const double _kCardSpace = 8;

class KazumiHomePage extends StatefulWidget {
  const KazumiHomePage({super.key});

  @override
  State<KazumiHomePage> createState() => _KazumiHomePageState();
}

class _KazumiHomePageState extends State<KazumiHomePage> {
  final ScrollController _scrollController = ScrollController();
  final List<MockBangumiItem> _list = [...mockBangumiList];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final base = _list.length;
    setState(() {
      for (var i = 0; i < mockBangumiList.length; i++) {
        final src = mockBangumiList[i];
        _list.add(MockBangumiItem(
          id: base + i + 1,
          nameCn: src.nameCn,
          name: src.name,
          imageUrl: 'https://picsum.photos/seed/load${base + i}/300/460',
          airDate: src.airDate,
          ratingScore: src.ratingScore,
          votes: src.votes,
          rank: src.rank,
          summary: src.summary,
        ));
      }
      _isLoadingMore = false;
    });
  }

  void _openDetail(MockBangumiItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            KazumiDetailPage(bangumiItem: item),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: _isLoadingMore ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _isLoadingMore
                  ? const LinearProgressIndicator(minHeight: 4)
                  : const SizedBox(height: 4),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                _kCardSpace, 0, _kCardSpace, 0),
            sliver: _contentGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        ),
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  Widget _contentGrid() {
    final width = MediaQuery.sizeOf(context).width;
    int crossCount = 3;
    if (width > 600) crossCount = 5;
    if (width > 840) crossCount = 6;

    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          mainAxisSpacing: _kCardSpace - 2,
          crossAxisSpacing: _kCardSpace,
          crossAxisCount: crossCount,
          mainAxisExtent:
              MediaQuery.of(context).size.width / crossCount / 0.65 +
                  MediaQuery.textScalerOf(context).scale(32.0),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _list[index];
            return BangumiCardV(
              bangumiItem: item,
              onTap: () => _openDetail(item),
            );
          },
          childCount: _list.length,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 120,
      elevation: 0,
      titleSpacing: 0,
      centerTitle: false,
      backgroundColor: theme.colorScheme.surface,
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: () {},
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: '历史记录',
          onPressed: () {},
          icon: const Icon(Icons.history),
        ),
      ],
      flexibleSpace: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxExtent =
                120 - MediaQuery.of(context).padding.top;
            final t = (1 -
                ((constraints.maxHeight - kToolbarHeight) /
                        (maxExtent - kToolbarHeight))
                    .clamp(0.0, 1.0));
            final fontWeight = t < 0.5 ? FontWeight.w700 : FontWeight.w500;
            final fontSize = lerpDouble(28, 20, t)!;
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16, top: 8, bottom: 8, right: 60),
                child: SizedBox(
                  height: 44,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '热门番组',
                          style: theme.textTheme.headlineMedium!.copyWith(
                            fontWeight: fontWeight,
                            fontSize: fontSize,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down,
                            size: fontSize, color: theme.iconTheme.color),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
