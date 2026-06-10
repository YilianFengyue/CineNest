import 'package:flutter/material.dart';

import '../../../services/bilibili_service.dart';
import 'bili_video_card.dart';

/// 播放页简介 Tab 内"相关视频"区域。
///
/// 自管理状态：首次可见时自动拉取，向下滚动到底自动分页。
/// 因为它嵌在外层 ListView 里，用 [SliverList] 不合适，
/// 这里直接用 Column 平铺卡片 + 底部加载指示器。
class BiliVideoSection extends StatefulWidget {
  const BiliVideoSection({
    super.key,
    required this.movieTitle,
    this.year,
  });

  final String movieTitle;
  final String? year;

  @override
  State<BiliVideoSection> createState() => BiliVideoSectionState();
}

class BiliVideoSectionState extends State<BiliVideoSection> {
  final List<BiliVideo> _videos = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _firstLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(BiliVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieTitle != widget.movieTitle || oldWidget.year != widget.year) {
      _videos.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
      _firstLoad = true;
      _loadMore();
    }
  }

  void loadMore() => _loadMore();

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await BilibiliService.getMovieVideos(
      movie: widget.movieTitle,
      year: widget.year,
      page: _page,
      pageSize: 12,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _firstLoad = false;
      if (result.videos.isEmpty && _videos.isEmpty) {
        _hasMore = false;
        return;
      }
      _videos.addAll(result.videos);
      _hasMore = result.hasMore;
      _page++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 首次加载中
    if (_firstLoad && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 无数据
    if (_videos.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.smart_display_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                '相关视频',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_videos.length} 个',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.open_in_new, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 2),
              Text(
                '打开 B 站',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // 视频列表
        ...List.generate(_videos.length, (i) {
          return BiliVideoCard(video: _videos[i]);
        }),

        // 底部加载 / 提示
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed: _loadMore,
                child: const Text('加载更多'),
              ),
            ),
          )
        else if (_videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '已加载全部',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outlineVariant,
                ),
              ),
            ),
          ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ),
      ],
    );
  }
}
