import 'package:cine_nest/models/video_source.dart';
import 'package:cine_nest/pages/player/services/source_api_service.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SourceDebugPanel extends StatefulWidget {
  const SourceDebugPanel({
    super.key,
    this.initialMovieName = 'The Shawshank Redemption',
    this.autoSearch = false,
  });

  final String initialMovieName;
  final bool autoSearch;

  @override
  State<SourceDebugPanel> createState() => _SourceDebugPanelState();
}

class _SourceDebugPanelState extends State<SourceDebugPanel> {
  final _api = const SourceApiService();
  late final TextEditingController _movieController;

  bool _loading = false;
  String _message = '';
  List<VideoSource> _sources = const [];

  @override
  void initState() {
    super.initState();
    _movieController = TextEditingController(text: widget.initialMovieName);
    if (widget.autoSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchSources();
        }
      });
    }
  }

  @override
  void dispose() {
    _movieController.dispose();
    super.dispose();
  }

  Future<void> _searchSources() async {
    final movieName = _movieController.text.trim();
    if (movieName.isEmpty) {
      setState(() => _message = 'Enter a movie name.');
      return;
    }

    setState(() {
      _loading = true;
      _message = 'Searching sources...';
      _sources = const [];
    });

    var warning = '';
    var webSources = <VideoSource>[];
    var biliSources = <VideoSource>[];

    try {
      webSources = await _api.searchSources(movieName);
    } catch (e) {
      warning = 'Backend source search failed, using fallback. ';
    }

    try {
      biliSources = await _api.searchBilibili('$movieName review');
    } catch (e) {
      warning = '${warning}Bilibili search failed, using fallback. ';
    }

    try {
      final realWebSources = webSources
          .where((source) => source.type == SourceType.web)
          .toList();
      final fallbackSources = _api.fallbackSources(movieName);
      final fallbackBili = fallbackSources
          .where((source) => source.id.startsWith('bili:'))
          .toList();
      final sourcePool = [
        ...webSources.where((source) => !source.id.startsWith('demo:')),
        ...biliSources,
        ...fallbackBili,
      ];

      final seen = <String>{};
      final merged = <VideoSource>[];
      for (final source in sourcePool) {
        if (seen.add(source.id)) {
          merged.add(source);
        }
      }
      setState(() {
        _sources = merged;
        final realHint = realWebSources.isEmpty
            ? 'No real MacCMS web source matched this keyword. '
            : '';
        _message = merged.isEmpty
            ? '${warning}No sources found.'
            : '$warning$realHint'
                  'Found ${merged.length} Bilibili/WebView source(s).';
      });
    } catch (e) {
      setState(() => _message = 'Search failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _playSource(VideoSource source) async {
    setState(() {
      _loading = true;
      _message = 'Parsing ${source.name}...';
    });

    try {
      final shouldParse =
          source.playUrl == null || _shouldParseBilibili(source);
      final parsed = shouldParse ? await _api.parseSource(source.id) : source;
      final playUrl = parsed.playUrl;
      if (playUrl == null || playUrl.isEmpty) {
        setState(() => _message = 'This source has no play URL.');
        return;
      }

      final title = parsed.name.isEmpty ? source.name : parsed.name;
      // 直链走统一的 /source-picker（会重新搜索并自动选源播放）；非直链仍走 webview。
      final route = _isDirectVideo(playUrl)
          ? Routes.sourcePicker
          : Routes.webviewPlayer;
      Get.toNamed(
        route,
        arguments: route == Routes.sourcePicker
            ? {'title': title}
            : {'url': playUrl, 'title': title},
      );
      setState(() => _message = 'Parsed successfully.');
    } catch (e) {
      setState(() => _message = 'Parse failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('/upgcxcode/');
  }

  bool _shouldParseBilibili(VideoSource source) {
    return source.type == SourceType.bilibili &&
        source.id.startsWith('bili:BV');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Member A source test', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _movieController,
          decoration: const InputDecoration(
            labelText: 'Movie name',
            hintText: 'The Shawshank Redemption',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loading ? null : _searchSources(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _searchSources,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: const Text('Search sources'),
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_message),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () => _playSource(
                  _api.fallbackSources(_movieController.text).first,
                ),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Open fixed demo video for player test'),
        ),
        const SizedBox(height: 12),
        for (final source in _sources)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(source.name),
              subtitle: Text(
                [
                  source.type.name,
                  if (source.quality != null && source.quality!.isNotEmpty)
                    source.quality!,
                  if (source.type == SourceType.bilibili)
                    'webview'
                  else if (source.id.startsWith('demo:'))
                    'test only'
                  else if (source.playUrl != null)
                    'ready',
                ].join(' / '),
              ),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: _loading ? null : () => _playSource(source),
            ),
          ),
      ],
    );
  }
}
