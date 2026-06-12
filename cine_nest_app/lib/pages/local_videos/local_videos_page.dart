import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/library_models.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/services/cast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// PC 影视库：后端扫盘 + TMDB 刮削 → 海报墙。
///
/// 每个条目两个动作：本机播放（media_kit 直接拉 PC 的 Range 流，mkv 也吃）
/// 和投屏到 PC（走 cast 链路，PC 端 CineLink 播，手机变遥控器）。
class LocalVideosPage extends StatefulWidget {
  const LocalVideosPage({super.key});

  @override
  State<LocalVideosPage> createState() => _LocalVideosPageState();
}

class _LocalVideosPageState extends State<LocalVideosPage> {
  LibraryView? _view;
  bool _loading = true;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool scan = false, bool force = false}) async {
    setState(() {
      _loading = !scan;
      _scanning = scan;
      _error = null;
    });
    try {
      final response = scan
          ? await Request().post(
              '${ApiConstants.libraryScan}${force ? '?force=true' : ''}',
            )
          : await Request().get(ApiConstants.library);
      if (response.statusCode != 200 || response.data is! Map) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _view = LibraryView.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (scan && mounted) {
        SmartDialog.showToast('扫描完成，共 ${_view!.total} 个视频');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _scanning = false;
        });
      }
    }
  }

  String _absoluteUrl(String path) {
    if (path.isEmpty || path.startsWith('http')) return path;
    final base = Request.dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base$path';
  }

  String _posterOf(LibraryMeta meta) =>
      _absoluteUrl(meta.posterProxy.isNotEmpty ? meta.posterProxy : meta.poster);

  // ── 动作 ─────────────────────────────────────────────────

  void _playOnPhone(String title, LibraryFile file) {
    Get.toNamed(
      Routes.sourcePicker,
      arguments: {
        'title': title,
        'url': _absoluteUrl(file.streamUrl),
        'sourceName': 'PC 影视库 · ${file.filename}',
      },
    );
  }

  void _castToPc(
    String title,
    LibraryFile file, {
    String cover = '',
    String episodeLabel = '',
    LibraryShow? show,
    int episodeIndex = 0,
  }) {
    Get.toNamed(Routes.castRemote, arguments: {
      'payload': CastLoadPayload(
        url: _absoluteUrl(file.streamUrl),
        title: title,
        cover: cover,
        episodeLabel: episodeLabel,
      ),
      // 剧集投屏给遥控页挂上选集（本地文件不用解析，直接换流地址）
      if (show != null) ...{
        'episodes': show.episodes.map((e) => e.episodeLabel).toList(),
        'currentIndex': episodeIndex,
        'resolveEpisode': (int index) async {
          final episode = show.episodes[index];
          return CastEpisodeBundle(
            payload: CastLoadPayload(
              url: _absoluteUrl(episode.file.streamUrl),
              title: title,
              cover: cover,
              episodeLabel: episode.episodeLabel,
            ),
          );
        },
      },
    });
  }

  Future<void> _editLibraryDir() async {
    String current = '';
    try {
      final response = await Request().get(ApiConstants.libraryConfig);
      if (response.data is Map) current = '${response.data['dir'] ?? ''}';
    } catch (_) {}
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('库目录（PC 上的路径）'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: r'例如 D:\Movies'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || value == current) return;
    try {
      final response = await Request().post(
        ApiConstants.libraryConfig,
        data: {'dir': value},
      );
      if (response.statusCode != 200) {
        throw Exception(
          response.data is Map
              ? '${response.data['detail'] ?? response.data}'
              : '${response.data}',
        );
      }
      await _load(scan: true);
    } catch (e) {
      SmartDialog.showToast('保存失败：$e');
    }
  }

  // ── 详情弹层 ──────────────────────────────────────────────

  void _showMovieSheet(LibraryMovie movie) {
    _showDetailSheet(
      meta: movie.meta,
      actions: [
        _ActionSpec(
          '本机播放',
          Icons.play_arrow_rounded,
          () => _playOnPhone(movie.meta.title, movie.file),
        ),
        _ActionSpec(
          '投屏到 PC',
          Icons.cast_rounded,
          () => _castToPc(
            movie.meta.title,
            movie.file,
            cover: _posterOf(movie.meta),
          ),
        ),
      ],
    );
  }

  void _showShowSheet(LibraryShow show) {
    _showDetailSheet(
      meta: show.meta,
      episodes: show.episodes,
      onPlayEpisode: (index) =>
          _playOnPhone(show.meta.title, show.episodes[index].file),
      onCastEpisode: (index) => _castToPc(
        show.meta.title,
        show.episodes[index].file,
        cover: _posterOf(show.meta),
        episodeLabel: show.episodes[index].episodeLabel,
        show: show,
        episodeIndex: index,
      ),
    );
  }

  void _showDetailSheet({
    required LibraryMeta meta,
    List<_ActionSpec> actions = const [],
    List<LibraryEpisode> episodes = const [],
    void Function(int index)? onPlayEpisode,
    void Function(int index)? onCastEpisode,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: episodes.isEmpty ? 0.45 : 0.6,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 90,
                    height: 130,
                    child: _PosterImage(url: _posterOf(meta)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (meta.year.isNotEmpty)
                            Text(meta.year, style: theme.textTheme.bodySmall),
                          if (meta.vote > 0)
                            Text(
                              '★ ${meta.vote.toStringAsFixed(1)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meta.overview.isEmpty ? '（暂无简介）' : meta.overview,
                        style: theme.textTheme.bodySmall,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (actions.isNotEmpty)
              Row(
                children: [
                  for (final (i, action) in actions.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: i == 0
                          ? FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                action.onTap();
                              },
                              icon: Icon(action.icon),
                              label: Text(action.label),
                            )
                          : FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.pop(context);
                                action.onTap();
                              },
                              icon: Icon(action.icon),
                              label: Text(action.label),
                            ),
                    ),
                  ],
                ],
              ),
            if (episodes.isNotEmpty) ...[
              Text('剧集（${episodes.length}）',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final (index, episode) in episodes.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(episode.episodeLabel),
                  subtitle: Text(
                    episode.file.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '本机播放',
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () {
                          Navigator.pop(context);
                          onPlayEpisode?.call(index);
                        },
                      ),
                      IconButton(
                        tooltip: '投屏到 PC',
                        icon: const Icon(Icons.cast_rounded),
                        onPressed: () {
                          Navigator.pop(context);
                          onCastEpisode?.call(index);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUnmatchedSheet(LibraryUnmatched item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.file.filename),
              subtitle: Text(_formatSize(item.file.size)),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('本机播放'),
              onTap: () {
                Navigator.pop(context);
                _playOnPhone(
                  item.parsedTitle.isEmpty
                      ? item.file.filename
                      : item.parsedTitle,
                  item.file,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cast_rounded),
              title: const Text('投屏到 PC'),
              onTap: () {
                Navigator.pop(context);
                _castToPc(
                  item.parsedTitle.isEmpty
                      ? item.file.filename
                      : item.parsedTitle,
                  item.file,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 视图 ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = _view;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PC 影视库'),
        actions: [
          IconButton(
            tooltip: '库目录',
            onPressed: _editLibraryDir,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            tooltip: '扫描并刮削',
            onPressed: _scanning ? null : () => _load(scan: true, force: true),
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : view == null || view.isEmpty
                  ? _EmptyView(onScan: () => _load(scan: true))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        slivers: [
                          if (view.movies.isNotEmpty) ...[
                            _sectionHeader(theme, '电影', view.movies.length),
                            _posterGrid(
                              view.movies.length,
                              (index) {
                                final movie = view.movies[index];
                                return _PosterCard(
                                  title: movie.meta.title,
                                  subtitle: movie.meta.year,
                                  posterUrl: _posterOf(movie.meta),
                                  onTap: () => _showMovieSheet(movie),
                                );
                              },
                            ),
                          ],
                          if (view.shows.isNotEmpty) ...[
                            _sectionHeader(theme, '剧集', view.shows.length),
                            _posterGrid(
                              view.shows.length,
                              (index) {
                                final show = view.shows[index];
                                return _PosterCard(
                                  title: show.meta.title,
                                  subtitle: '${show.episodes.length} 集',
                                  posterUrl: _posterOf(show.meta),
                                  onTap: () => _showShowSheet(show),
                                );
                              },
                            ),
                          ],
                          if (view.unmatched.isNotEmpty) ...[
                            _sectionHeader(
                              theme,
                              '未识别',
                              view.unmatched.length,
                            ),
                            SliverList.builder(
                              itemCount: view.unmatched.length,
                              itemBuilder: (context, index) {
                                final item = view.unmatched[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.insert_drive_file_outlined,
                                  ),
                                  title: Text(
                                    item.file.filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(_formatSize(item.file.size)),
                                  onTap: () => _showUnmatchedSheet(item),
                                );
                              },
                            ),
                          ],
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterGrid(int count, Widget Function(int index) builder) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2 / 3.6,
        ),
        itemCount: count,
        itemBuilder: (context, index) => builder(index),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _ActionSpec {
  const _ActionSpec(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.title,
    required this.subtitle,
    required this.posterUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String posterUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                child: _PosterImage(url: posterUrl),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        color: theme.colorScheme.outline,
        size: 32,
      ),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('影视库还是空的', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '在 PC 库目录放视频文件后点扫描',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onScan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('扫描并刮削'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
