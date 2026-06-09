import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/services/tmdb_direct_service.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_home_controller.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_detail_page.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_search_page.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_history_page.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/bangumi_card_v.dart';

const double _kCardSpace = 8;

class KazumiHomePage extends StatefulWidget {
  const KazumiHomePage({super.key});

  @override
  State<KazumiHomePage> createState() => _KazumiHomePageState();
}

class _KazumiHomePageState extends State<KazumiHomePage> {
  final ScrollController _scrollController = ScrollController();
  late final KazumiHomeController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(KazumiHomeController());
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
        !_ctrl.isLoadingMore.value) {
      _ctrl.loadMore();
    }
  }

  void _showCategoryMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      constraints: BoxConstraints(
        maxHeight: 56.0 * 5 + 48,
      ),
      builder: (sheetCtx) {
        return ListView.builder(
          itemCount: homeCategories.length,
          itemBuilder: (_, i) {
            final cat = homeCategories[i];
            final active = cat.type == _ctrl.currentCategory.value.type &&
                cat.genreId == _ctrl.currentCategory.value.genreId;
            return ListTile(
              title: Text(
                cat.label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  color: active
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
              ),
              trailing: active ? Icon(Icons.check, color: Theme.of(sheetCtx).colorScheme.primary) : null,
              onTap: () {
                Navigator.pop(sheetCtx);
                _ctrl.switchCategory(cat);
                _scrollController.animateTo(0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut);
              },
            );
          },
        );
      },
    );
  }

  void _openDetail(TmdbMediaItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => KazumiDetailPage(item: item),
        transitionsBuilder: (_, animation, __, child) {
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
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.trendingList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_ctrl.errorMsg.isNotEmpty && _ctrl.trendingList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_ctrl.errorMsg.value),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _ctrl.loadTrending,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Obx(() => AnimatedOpacity(
                    opacity: _ctrl.isLoadingMore.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _ctrl.isLoadingMore.value
                        ? const LinearProgressIndicator(minHeight: 4)
                        : const SizedBox(height: 4),
                  )),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(_kCardSpace, 0, _kCardSpace, 0),
              sliver: _contentGrid(),
            ),
          ],
        );
      }),
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

    return Obx(() => SliverPadding(
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
                final item = _ctrl.trendingList[index];
                return BangumiCardV(
                  item: item,
                  onTap: () => _openDetail(item),
                );
              },
              childCount: _ctrl.trendingList.length,
            ),
          ),
        ));
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
      automaticallyImplyLeading: false,
      backgroundColor: theme.colorScheme.surface,
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KazumiSearchPage()),
          ),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: '历史记录',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KazumiHistoryPage()),
          ),
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
                  child: Obx(() {
                    final label = _ctrl.currentCategory.value.label;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showCategoryMenu(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
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
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
