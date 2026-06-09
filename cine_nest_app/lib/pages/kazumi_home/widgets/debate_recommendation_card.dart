import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';
import 'package:cine_nest/services/debate_recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class DebateRecommendationCard extends StatefulWidget {
  const DebateRecommendationCard({
    super.key,
    required this.detail,
    this.episodeName,
  });

  final AggregatorMediaDetail detail;
  final String? episodeName;

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
    final result = Map<String, dynamic>.from(
      (_payload?['result'] as Map?) ?? const {},
    );
    final sections = (result['render_sections'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _CommitteeHeader(
          result: result,
          loading: _loading,
          error: _error,
          onGenerate: _generate,
        ),
        if (result.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final section in sections) _RenderSection(section: section),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新讨论'),
          ),
        ],
      ],
    );
  }
}

class _CommitteeHeader extends StatelessWidget {
  const _CommitteeHeader({
    required this.result,
    required this.loading,
    required this.error,
    required this.onGenerate,
  });

  final Map<String, dynamic> result;
  final bool loading;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_2_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 推荐委员会',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (result.isNotEmpty) _ScorePill(score: result['final_score']),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.isEmpty
                  ? '让口味官、资源官、口碑官和反方官一起评审这部片。'
                  : result['final_reason']?.toString() ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            if (result.isEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: loading ? null : onGenerate,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(loading ? '委员会讨论中' : '生成委员会结论'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tip in (result['risk_tips'] as List? ?? const []))
                    Chip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: Text(tip.toString()),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RenderSection extends StatelessWidget {
  const _RenderSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final type = section['type']?.toString() ?? '';
    switch (type) {
      case 'hot_comments':
        return _HotCommentsSection(section: section);
      case 'highlight_buttons':
        return _HighlightButtonsSection(section: section);
      case 'danmaku_seeds':
        return _DanmakuSeedSection(section: section);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _HotCommentsSection extends StatelessWidget {
  const _HotCommentsSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final items = (section['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section['title']?.toString() ?? '最热评论',
          trailing: '最热',
        ),
        for (final item in items) _CommentTile(item: item),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final replies = (item['reply_preview'] as List? ?? const [])
        .whereType<Map>()
        .map((reply) => Map<String, dynamic>.from(reply))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(seed: item['avatar_seed']?.toString() ?? ''),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item['author']?.toString() ?? 'AI 评论员',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Badge(text: item['badge']?.toString() ?? 'AI'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['time_label'] ?? '刚刚'} · IP属地：${item['location'] ?? 'AI 推荐委员会'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['content']?.toString() ?? '',
                  style: theme.textTheme.bodyLarge,
                ),
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reply in replies)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${reply['author'] ?? '委员会成员'}：',
                                      style: TextStyle(color: cs.primary),
                                    ),
                                    TextSpan(
                                      text: reply['content']?.toString() ?? '',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 16, color: cs.outline),
                    const SizedBox(width: 4),
                    Text('回复', style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Icon(
                      Icons.thumb_down_alt_outlined,
                      size: 17,
                      color: cs.outline,
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 17,
                      color: cs.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['likes'] ?? 0}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightButtonsSection extends StatelessWidget {
  const _HighlightButtonsSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final items = (section['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: section['title']?.toString() ?? '精彩片段'),
        const SizedBox(height: 2),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => _handleHighlight(context, item),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${item['button_text'] ?? '查看片段'} · ${item['label'] ?? '精彩片段'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleHighlight(BuildContext context, Map<String, dynamic> item) {
    final action = Map<String, dynamic>.from((item['action'] as Map?) ?? {});
    final startMs = action['start_ms'];
    if (startMs is int && startMs > 0) {
      SmartDialog.showToast('后续接播放器 seek: ${startMs}ms');
      return;
    }
    SmartDialog.showToast(item['why']?.toString() ?? '暂无精确时间轴，先作为片段提示');
  }
}

class _DanmakuSeedSection extends StatelessWidget {
  const _DanmakuSeedSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final seeds = (section['seeds'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    if (seeds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: section['title']?.toString() ?? '弹幕种子'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final seed in seeds)
              Chip(
                avatar: const Icon(Icons.subtitles_outlined, size: 16),
                label: Text(seed),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null) ...[
            Icon(Icons.sort_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              trailing!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${score ?? '--'} 分',
        style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.deepPurple,
      Colors.pink,
      Colors.orange,
    ];
    final index =
        seed.codeUnits.fold<int>(0, (sum, item) => sum + item) % colors.length;
    return CircleAvatar(
      radius: 18,
      backgroundColor: colors[index].withValues(alpha: 0.18),
      child: Icon(Icons.smart_toy_outlined, size: 18, color: colors[index]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
