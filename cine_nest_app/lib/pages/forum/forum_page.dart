import 'package:cine_nest/models/forum.dart';
import 'package:cine_nest/pages/forum/forum_api.dart';
import 'package:cine_nest/pages/forum/forum_identity.dart';
import 'package:cine_nest/pages/forum/forum_visual.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final _api = const ForumApi();
  final _searchController = TextEditingController();
  List<ForumPostSummary> _posts = const [];
  bool _loading = true;
  String _sort = 'latest';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.listPosts(
        clientId: ForumIdentity.clientId,
        sort: _sort,
        keyword: _searchController.text,
      );
      _posts = result.items;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCompose() async {
    final ok = await Get.toNamed(Routes.forumCompose);
    if (ok == true) _load();
  }

  Future<void> _openDetail(ForumPostSummary post) async {
    await Get.toNamed(Routes.forumDetail, arguments: {'postId': post.id});
    _load();
  }

  void _setSort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopTab(
              label: '推荐',
              selected: _sort == 'latest',
              onTap: () => _setSort('latest'),
            ),
            const SizedBox(width: 28),
            _TopTab(
              label: '热门',
              selected: _sort == 'hot',
              onTap: () => _setSort('hot'),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _openCompose,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xffff9f1a),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜电影、帖子、昵称',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                filled: true,
                fillColor: const Color(0xfff4f4f4),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _posts.isEmpty
                        ? _EmptyForum(onPost: _openCompose)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: _posts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _FeedPostCard(
                                post: _posts[index],
                                onTap: () => _openDetail(_posts[index]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? const Color(0xff202124) : const Color(0xff9a9a9a),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 30 : 0,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xffffb000),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.post, required this.onTap});

  final ForumPostSummary post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleLine = post.title.trim();
    final contentLine = post.contentPreview.trim();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: post.authorName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xffe77817),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const _VerifyBadge(),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_shortTime(post.createdAt)}  来自 CineNest 电影社区',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xff8f8f8f),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xffb9b9b9)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                titleLine,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              if (contentLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  contentLine,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    color: const Color(0xff292929),
                  ),
                ),
              ],
              if ((post.imageUrl?.trim().isNotEmpty ?? false) ||
                  (post.sticker?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                ForumVisual(
                  imageUrl: post.imageUrl,
                  sticker: post.sticker,
                  compact: true,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((post.likeCount + post.commentCount) >= 10)
                    const _HotPill(text: '热帖指数 30000+'),
                  if ((post.movieTitle ?? '').trim().isNotEmpty)
                    _MoviePill(text: post.movieTitle!.trim()),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Row(
                children: [
                  _FeedAction(
                    icon: Icons.ios_share_rounded,
                    text: '${_stableShareCount(post.id)}',
                  ),
                  _FeedAction(
                    icon: Icons.mode_comment_outlined,
                    text: '${post.commentCount}',
                  ),
                  _FeedAction(
                    icon: post.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.local_fire_department_rounded,
                    text: '${post.likeCount}',
                    highlighted: post.likedByMe || post.likeCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortTime(String raw) {
    if (raw.length >= 16) return raw.substring(5, 16);
    return raw;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xffffecd1),
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xffd36d00),
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ),
        const Positioned(
          right: -1,
          bottom: -1,
          child: _VerifyDot(),
        ),
      ],
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  const _VerifyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xfffff0cc),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'V',
        style: TextStyle(
          color: Color(0xffff9f1a),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _VerifyDot extends StatelessWidget {
  const _VerifyDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xffffb000),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
    );
  }
}

class _HotPill extends StatelessWidget {
  const _HotPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffffded6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffff5a4a),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '爆文',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Color(0xff777777))),
        ],
      ),
    );
  }
}

class _MoviePill extends StatelessWidget {
  const _MoviePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff6f6f6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_creation_rounded, size: 15, color: Color(0xff777777)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xff666666)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedAction extends StatelessWidget {
  const _FeedAction({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? const Color(0xffff7a00) : const Color(0xff777777);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyForum extends StatelessWidget {
  const _EmptyForum({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('还没有帖子，来抢第一条热评吧。'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPost, child: const Text('发第一帖')),
          ],
        ),
      ),
    );
  }
}

int _stableShareCount(String seed) {
  var total = 0;
  for (final unit in seed.codeUnits) {
    total = (total + unit * 17) % 900;
  }
  return total + 88;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
