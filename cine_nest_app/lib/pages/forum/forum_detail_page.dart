import 'package:cine_nest/models/forum.dart';
import 'package:cine_nest/pages/forum/forum_api.dart';
import 'package:cine_nest/pages/forum/forum_identity.dart';
import 'package:cine_nest/pages/forum/forum_visual.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForumDetailPage extends StatefulWidget {
  const ForumDetailPage({super.key});

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  final _api = const ForumApi();
  final _commentController = TextEditingController();
  final _nicknameController = TextEditingController(
    text: ForumIdentity.nickname,
  );
  late final String _postId;
  ForumPostDetail? _post;
  List<ForumComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : <String, dynamic>{};
    _postId = args['postId']?.toString() ?? '';
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_postId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Post id is missing.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getPost(_postId, ForumIdentity.clientId);
      _post = detail.post;
      _comments = detail.comments;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    try {
      final result = await _api.toggleLike(post.id, ForumIdentity.clientId);
      setState(() {
        _post = ForumPostDetail(
          id: post.id,
          title: post.title,
          content: post.content,
          authorName: post.authorName,
          likeCount: result['like_count'] is int
              ? result['like_count'] as int
              : post.likeCount,
          commentCount: post.commentCount,
          likedByMe: result['liked'] == true,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          movieId: post.movieId,
          movieTitle: post.movieTitle,
          imageUrl: post.imageUrl,
          sticker: post.sticker,
        );
      });
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _sendComment() async {
    final post = _post;
    final nickname = _nicknameController.text.trim();
    final content = _commentController.text.trim();
    if (post == null || nickname.isEmpty || content.isEmpty) {
      _showSnack('Nickname and comment are required.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ForumIdentity.saveNickname(nickname);
      final comment = await _api.createComment(
        postId: post.id,
        content: content,
        authorName: nickname,
        clientId: ForumIdentity.clientId,
      );
      _commentController.clear();
      setState(() {
        _comments = [..._comments, comment];
        _post = ForumPostDetail(
          id: post.id,
          title: post.title,
          content: post.content,
          authorName: post.authorName,
          likeCount: post.likeCount,
          commentCount: post.commentCount + 1,
          likedByMe: post.likedByMe,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          movieId: post.movieId,
          movieTitle: post.movieTitle,
          imageUrl: post.imageUrl,
          sticker: post.sticker,
        );
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.4,
        titleSpacing: 0,
        title: post == null
            ? const Text('帖子详情')
            : Row(
                children: [
                  _SmallAvatar(name: post.authorName),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Refresh',
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      bottomNavigationBar: post == null
          ? null
          : _BottomActions(
              post: post,
              onLike: _toggleLike,
              onCommentTap: () {},
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : post == null
          ? _ErrorView(message: 'Post not found.', onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  _PostDetailCard(post: post),
                  _SearchSuggestion(post: post),
                  _StatsBar(post: post),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    color: const Color(0xfff7f7f7),
                    child: const Text(
                      '友好讨论会让电影更好看，请谨慎评论',
                      style: TextStyle(color: Color(0xff8a8a8a)),
                    ),
                  ),
                  _CommentComposer(
                    nicknameController: _nicknameController,
                    commentController: _commentController,
                    sending: _sending,
                    onSend: _sendComment,
                  ),
                  const SizedBox(height: 10),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('还没有评论，来当第一位影评人。')),
                    )
                  else
                    ..._comments.map(
                      (comment) => _CommentCard(comment: comment),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PostDetailCard extends StatelessWidget {
  const _PostDetailCard({required this.post});

  final ForumPostDetail post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                    const SizedBox(height: 4),
                    Text(
                      '${_shortTime(post.createdAt)}  来自 CineNest 电影社区',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xff8f8f8f),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: const Color(0xff252525),
            ),
          ),
          if ((post.imageUrl?.trim().isNotEmpty ?? false) ||
              (post.sticker?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            ForumVisual(imageUrl: post.imageUrl, sticker: post.sticker),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              if ((post.likeCount + post.commentCount) >= 10)
                const _HotPill(text: '热文指数30000+'),
              if ((post.movieTitle ?? '').trim().isNotEmpty)
                _SearchChip(text: post.movieTitle!.trim()),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortTime(String raw) {
    if (raw.length >= 16) return raw.substring(5, 16);
    return raw;
  }
}

class _SearchSuggestion extends StatelessWidget {
  const _SearchSuggestion({required this.post});

  final ForumPostDetail post;

  @override
  Widget build(BuildContext context) {
    final title = (post.movieTitle ?? post.title).trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('大家都在搜', style: TextStyle(color: Color(0xff999999))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _SearchChip(text: '$title 影评'),
              const _SearchChip(text: '今晚看什么电影'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.post});

  final ForumPostDetail post;

  @override
  Widget build(BuildContext context) {
    final shares = _stableShareCount(post.id);
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xffeeeeee), width: 8),
          bottom: BorderSide(color: Color(0xffeeeeee)),
        ),
      ),
      child: Row(
        children: [
          _StatsItem(label: '转发', value: '$shares'),
          _StatsItem(
            label: '评论',
            value: '${post.commentCount}',
            selected: true,
          ),
          _StatsItem(label: '赞', value: '${post.likeCount}'),
        ],
      ),
    );
  }
}

class _StatsItem extends StatelessWidget {
  const _StatsItem({
    required this.label,
    required this.value,
    this.selected = false,
  });

  final String label;
  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 17, color: Color(0xff9a9a9a)),
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xff202124)
                          : const Color(0xff777777),
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 4,
            width: selected ? 32 : 0,
            decoration: BoxDecoration(
              color: const Color(0xffffb000),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.nicknameController,
    required this.commentController,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController nicknameController;
  final TextEditingController commentController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: nicknameController,
            maxLength: 24,
            decoration: InputDecoration(
              counterText: '',
              labelText: '昵称',
              filled: true,
              fillColor: const Color(0xfff7f7f7),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  maxLength: 800,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '写评论...',
                    filled: true,
                    fillColor: const Color(0xfff7f7f7),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffff9f1a),
                  foregroundColor: Colors.white,
                ),
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('发送'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final ForumComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallAvatar(name: comment.authorName),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xff666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  comment.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortTime(comment.createdAt),
                        style: const TextStyle(color: Color(0xff9a9a9a)),
                      ),
                    ),
                    const _TinyAction(icon: Icons.sentiment_neutral_rounded),
                    const SizedBox(width: 16),
                    const _TinyAction(icon: Icons.mode_comment_outlined),
                    const SizedBox(width: 16),
                    const _TinyAction(icon: Icons.thumb_up_alt_outlined),
                  ],
                ),
                const Divider(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortTime(String raw) {
    if (raw.length >= 16) return raw.substring(5, 16);
    return raw;
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.post,
    required this.onLike,
    required this.onCommentTap,
  });

  final ForumPostDetail post;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    final likeColor = post.likedByMe
        ? const Color(0xffff7a00)
        : const Color(0xff202124);
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffeeeeee))),
        ),
        child: Row(
          children: [
            _BottomAction(
              icon: Icons.ios_share_rounded,
              text: '${_stableShareCount(post.id)}',
            ),
            _BottomAction(
              icon: Icons.mode_comment_outlined,
              text: '${post.commentCount}',
              onTap: onCommentTap,
            ),
            _BottomAction(
              icon: post.likedByMe
                  ? Icons.favorite_rounded
                  : Icons.local_fire_department_rounded,
              text: '${post.likeCount}',
              color: likeColor,
              onTap: onLike,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.text,
    this.color = const Color(0xff202124),
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _SmallAvatar(name: name, radius: 24),
        const Positioned(right: -1, bottom: -1, child: _VerifyDot()),
      ],
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.name, this.radius = 18});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xffffecd1),
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xffd36d00),
          fontWeight: FontWeight.w900,
          fontSize: radius * 0.78,
        ),
      ),
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

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xff777777)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xff555555)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotPill extends StatelessWidget {
  const _HotPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _TinyAction extends StatelessWidget {
  const _TinyAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 19, color: const Color(0xffa0a0a0));
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
