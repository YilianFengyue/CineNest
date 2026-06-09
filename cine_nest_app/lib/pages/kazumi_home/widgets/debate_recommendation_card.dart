import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';
import 'package:cine_nest/services/debate_recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 主组件
// ─────────────────────────────────────────────────────────────────────────────

class DebateRecommendationCard extends StatefulWidget {
  const DebateRecommendationCard({
    super.key,
    required this.detail,
    this.episodeName,
    this.onSeek,
  });

  final AggregatorMediaDetail detail;
  final String? episodeName;
  final void Function(int episodeIndex, int? startMs)? onSeek;

  @override
  State<DebateRecommendationCard> createState() =>
      _DebateRecommendationCardState();
}

class _DebateRecommendationCardState extends State<DebateRecommendationCard> {
  final _service = DebateRecommendationService();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _payload;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _service.generate(
        detail: widget.detail,
        episodeName: widget.episodeName,
      );
      if (!mounted) return;
      setState(() => _payload = payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _asMap(_payload?['result']);
    final sections =
        (result['render_sections'] as List?)
            ?.whereType<Map>()
            .map(_asMap)
            .toList() ??
        const [];

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 32),
      children: [
        // 顶部委员会卡片
        _CommitteeHeader(
          envelope: _payload ?? const {},
          result: result,
          loading: _loading,
          error: _error,
          onGenerate: _generate,
        ),
        if (result.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final section in sections)
            _RenderSection(section: section, onSeek: widget.onSeek),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新讨论'),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 委员会头部卡片
// ─────────────────────────────────────────────────────────────────────────────

class _CommitteeHeader extends StatelessWidget {
  const _CommitteeHeader({
    required this.result,
    required this.envelope,
    required this.loading,
    required this.error,
    required this.onGenerate,
  });

  final Map<String, dynamic> result;
  final Map<String, dynamic> envelope;
  final bool loading;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasResult = result.isNotEmpty;
    final generatedBy = envelope['generated_by']?.toString() ?? '';
    final modelUsed = envelope['model_used']?.toString() ?? '';
    final fallbackReason = envelope['fallback_reason']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_2_rounded, size: 22, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI 推荐委员会',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasResult) _ScorePill(score: result['final_score']),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasResult
                    ? result['final_reason']?.toString() ?? ''
                    : '让口味官、资源官、口碑官和反方官一起评审这部片。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              if (hasResult &&
                  (result['risk_tips'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tip in result['risk_tips'] as List)
                      _RiskChip(text: tip.toString()),
                  ],
                ),
              ],
              if (hasResult && generatedBy.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  generatedBy == 'llm'
                      ? 'LLM 生成${modelUsed.isNotEmpty ? ' · $modelUsed' : ''}'
                      : 'Fallback 兜底${fallbackReason.isNotEmpty ? ' · $fallbackReason' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: generatedBy == 'llm' ? cs.primary : cs.error,
                  ),
                ),
              ],
              if (!hasResult) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: loading ? null : onGenerate,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(loading ? '委员会讨论中…' : '生成委员会结论'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// render_sections 分发
// ─────────────────────────────────────────────────────────────────────────────

class _RenderSection extends StatelessWidget {
  const _RenderSection({required this.section, this.onSeek});

  final Map<String, dynamic> section;
  final void Function(int, int?)? onSeek;

  @override
  Widget build(BuildContext context) {
    switch (section['type']?.toString()) {
      case 'hot_comments':
        return _HotCommentsSection(section: section);
      case 'highlight_buttons':
        return _HighlightSection(section: section, onSeek: onSeek);
      case 'danmaku_seeds':
        return _DanmakuSection(section: section);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 最热评论区 (PilipiliPlus 风格)
// ─────────────────────────────────────────────────────────────────────────────

class _HotCommentsSection extends StatelessWidget {
  const _HotCommentsSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final items =
        (section['items'] as List?)?.whereType<Map>().map(_asMap).toList() ??
        const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SortHeader(
          title: section['title']?.toString() ?? '最热评论',
          count: items.length,
        ),
        for (int i = 0; i < items.length; i++) ...[
          _CommentItem(item: items[i]),
          if (i < items.length - 1)
            Divider(
              indent: 58,
              endIndent: 15,
              height: 0.5,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.08),
            ),
        ],
      ],
    );
  }
}

// ── 排序头 ──

class _SortHeader extends StatelessWidget {
  const _SortHeader({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const Spacer(),
          Icon(Icons.sort_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '最热',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 单条评论 (PilipiliPlus 级别) ──

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final seed = item['avatar_seed']?.toString() ?? '';
    final replies =
        (item['reply_preview'] as List?)
            ?.whereType<Map>()
            .map(_asMap)
            .toList() ??
        const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(seed: seed, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 用户名行 ──
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item['author']?.toString() ?? 'AI 评论员',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Badge(text: item['badge']?.toString() ?? 'AI'),
                  ],
                ),
                const SizedBox(height: 2),
                // ── 时间 + IP ──
                Text(
                  '${item['time_label'] ?? '刚刚'} · IP属地：${item['location'] ?? 'AI 推荐委员会'}',
                  style: TextStyle(
                    fontSize: theme.textTheme.labelSmall!.fontSize,
                    color: cs.outline,
                  ),
                ),
                const SizedBox(height: 10),
                // ── 正文 ──
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 6),
                  child: Text(
                    item['content']?.toString() ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.75),
                  ),
                ),
                // ── 楼中楼回复 ──
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReplyPreviewBox(replies: replies),
                ],
                const SizedBox(height: 6),
                // ── 操作栏 ──
                _ActionBar(
                  likes: _toInt(item['likes']),
                  dislikes: _toInt(item['dislikes']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 楼中楼回复 ──

class _ReplyPreviewBox extends StatelessWidget {
  const _ReplyPreviewBox({required this.replies});

  final List<Map<String, dynamic>> replies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.onInverseSurface,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < replies.length; i++)
            Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                i == 0 ? 8 : 4,
                8,
                i == replies.length - 1 ? 8 : 4,
              ),
              child: Text.rich(
                style: TextStyle(
                  fontSize: theme.textTheme.bodyMedium!.fontSize,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  height: 1.6,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${replies[i]['author'] ?? '委员会成员'}',
                      style: TextStyle(color: cs.primary),
                    ),
                    const TextSpan(text: '：'),
                    TextSpan(text: replies[i]['content']?.toString() ?? ''),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 操作栏（回复 / 踩 / 赞） ──

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.likes, this.dislikes = 0});

  final int likes;
  final int dislikes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final outline = cs.outline;
    final style = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 2),
          SizedBox(
            height: 32,
            child: TextButton(
              style: style,
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: outline.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '回复',
                    style: TextStyle(
                      fontSize: theme.textTheme.labelSmall!.fontSize,
                      color: outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            child: TextButton(
              style: style,
              onPressed: () {},
              child: Icon(
                Icons.thumb_down_alt_outlined,
                size: 16,
                color: outline,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: TextButton(
              style: style,
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 16, color: outline),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(likes),
                    style: TextStyle(
                      fontSize: theme.textTheme.labelSmall!.fontSize,
                      color: outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 精彩片段区
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightSection extends StatelessWidget {
  const _HighlightSection({required this.section, this.onSeek});

  final Map<String, dynamic> section;
  final void Function(int, int?)? onSeek;

  @override
  Widget build(BuildContext context) {
    final items =
        (section['items'] as List?)?.whereType<Map>().map(_asMap).toList() ??
        const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section['title']?.toString() ?? '精彩片段',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () => _handleHighlight(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['label']?.toString() ?? '精彩片段',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((item['why']?.toString() ?? '').isNotEmpty)
                                Text(
                                  item['why']!.toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: cs.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleHighlight(Map<String, dynamic> item) {
    final action = _asMap(item['action']);
    final startMs = action['start_ms'];
    final episodeIndex = _toInt(action['episode_index']);
    if (startMs is int && startMs > 0) {
      onSeek?.call(episodeIndex, startMs);
      SmartDialog.showToast('跳转到 ${_formatMs(startMs)}');
      return;
    }
    onSeek?.call(episodeIndex, null);
    SmartDialog.showToast(item['why']?.toString() ?? '暂无精确时间轴');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 弹幕种子区
// ─────────────────────────────────────────────────────────────────────────────

class _DanmakuSection extends StatelessWidget {
  const _DanmakuSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final seeds =
        (section['seeds'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    if (seeds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section['title']?.toString() ?? '弹幕种子',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final seed in seeds)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    seed,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 原子组件
// ─────────────────────────────────────────────────────────────────────────────

const _kAvatarAssets = [
  'assets/avators/avatar1.jpg',
  'assets/avators/avatar2.jpg',
  'assets/avators/avatar3.jpg',
  'assets/avators/avator4.jpg',
  'assets/avators/avator5.jpg',
  'assets/avators/avator6.jpg',
  'assets/avators/avator7.jpg',
  'assets/avators/avator8.jpg',
];

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, this.size = 34});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum * 31 + c);
    final index = hash.abs() % _kAvatarAssets.length;
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: AssetImage(_kAvatarAssets[index]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final Object? score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = _toInt(score);
    final color = value >= 80
        ? const Color(0xFF2E7D32)
        : value >= 60
        ? cs.primary
        : const Color(0xFFE65100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${score ?? '--'} 分',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: cs.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _formatCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  return '$n';
}

String _formatMs(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  final sec = s % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}
