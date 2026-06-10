import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/taste_dna.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class TasteDnaPage extends StatefulWidget {
  const TasteDnaPage({super.key});

  @override
  State<TasteDnaPage> createState() => _TasteDnaPageState();
}

class _TasteDnaPageState extends State<TasteDnaPage> {
  TasteDna? _dna;
  bool _loading = true;
  bool _generating = false;
  bool _pollingAvatar = false;
  String? _error;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _warning = null;
    });
    try {
      final response = await Request().get(ApiConstants.tasteDna);
      if (response.statusCode != 200) {
        throw Exception(response.data is Map
            ? (response.data['message'] ?? response.data['detail'] ?? response.data).toString()
            : response.data.toString());
      }
      _dna = TasteDna.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateAvatar() async {
    setState(() {
      _generating = true;
      _error = null;
      _warning = null;
    });
    try {
      final response = await Request().post(
        ApiConstants.tasteDnaAvatarGenerate,
        queryParameters: {'force': true},
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 180),
        ),
      );
      if (response.statusCode != 200) {
        throw Exception(response.data is Map
            ? (response.data['detail'] ?? response.data['message'] ?? response.data).toString()
            : response.data.toString());
      }
      final avatar = TasteAvatarResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      final oldAvatarUrl = _dna?.avatarUrl;
      await _load();
      if (mounted && avatar.warning != null && avatar.warning!.isNotEmpty) {
        setState(() => _warning = avatar.warning);
        _pollAvatarUpdate(oldAvatarUrl);
      }
      if (mounted && avatar.avatarUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              avatar.warning == null || avatar.warning!.isEmpty
                  ? 'Avatar generated.'
                  : 'New generation failed, kept previous avatar.',
            ),
          ),
        );
      }
    } catch (e) {
      _error = _readError(e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pollAvatarUpdate(String? oldAvatarUrl) async {
    if (_pollingAvatar) return;
    _pollingAvatar = true;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) break;
      try {
        final response = await Request().get(ApiConstants.tasteDna);
        if (response.statusCode != 200 || response.data is! Map) continue;
        final next = TasteDna.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final changed = next.avatarUrl != null &&
            next.avatarUrl!.isNotEmpty &&
            next.avatarUrl != oldAvatarUrl;
        if (changed) {
          setState(() {
            _dna = next;
            _warning = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New avatar is ready.')),
          );
          break;
        }
      } catch (_) {
        // Keep polling while the backend finishes the background generation.
      }
    }
    _pollingAvatar = false;
  }

  String _readError(Object error) {
    final text = error.toString();
    final detail = RegExp(r'detail: ([^,}]+)').firstMatch(text);
    return detail?.group(1) ?? text;
  }

  String _absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = Request.dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final dna = _dna;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taste DNA'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : dna == null
              ? _ErrorView(error: _error ?? 'Taste DNA load failed.', onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _AvatarCard(
                      imageUrl: _absoluteUrl(dna.avatarUrl),
                      generating: _generating,
                      onGenerate: _generateAvatar,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _error!),
                    ],
                    if (_warning != null) ...[
                      const SizedBox(height: 12),
                      _WarningBanner(message: _warning!),
                    ],
                    const SizedBox(height: 16),
                    _SummaryCard(dna: dna),
                    const SizedBox(height: 16),
                    _GenreScoreCard(scores: dna.topGenres),
                    const SizedBox(height: 16),
                    _TagSection(title: 'Mood tags', tags: dna.moodTags),
                    const SizedBox(height: 12),
                    _TagSection(title: 'Avoid genres', tags: dna.avoidGenres),
                    const SizedBox(height: 12),
                    _TagSection(title: 'Data notes', tags: dna.eraTags),
                  ],
                ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.imageUrl,
    required this.generating,
    required this.onGenerate,
  });

  final String imageUrl;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: imageUrl.isEmpty
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.auto_awesome_rounded, size: 72),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_rounded)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_rounded),
                label: Text(imageUrl.isEmpty ? 'Generate Q avatar' : 'Regenerate Q avatar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.dna});

  final TasteDna dna;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(dna.summary),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: dna.confidence.clamp(0.0, 1.0).toDouble(),
            ),
            const SizedBox(height: 6),
            Text('Confidence: ${(dna.confidence * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

class _GenreScoreCard extends StatelessWidget {
  const _GenreScoreCard({required this.scores});

  final List<TasteScore> scores;

  @override
  Widget build(BuildContext context) {
    final maxScore = scores.isEmpty
        ? 1.0
        : scores.map((item) => item.score).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type proportion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (scores.isEmpty)
              const Text('No genre preference yet.')
            else
              ...scores.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 76, child: Text(item.name)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: maxScore <= 0 ? 0 : item.score / maxScore,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(item.score.toStringAsFixed(0)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (tags.isEmpty)
              const Text('None')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: cs.onTertiaryContainer),
        ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
