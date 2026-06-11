import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/local_video.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocalVideosPage extends StatefulWidget {
  const LocalVideosPage({super.key});

  @override
  State<LocalVideosPage> createState() => _LocalVideosPageState();
}

class _LocalVideosPageState extends State<LocalVideosPage> {
  final _roomController = TextEditingController(text: 'cinenest');
  List<LocalVideo> _videos = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool rescan = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = rescan
          ? await Request().post(ApiConstants.localVideosRescan)
          : await Request().get(ApiConstants.localVideos);
      if (response.statusCode != 200) {
        throw Exception(
          response.data is Map
              ? (response.data['message'] ??
                        response.data['detail'] ??
                        response.data)
                    .toString()
              : response.data.toString(),
        );
      }
      final data = response.data is List ? response.data as List : const [];
      _videos = data
          .whereType<Map>()
          .map((item) => LocalVideo.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = Request.dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base$path';
  }

  String _pcPlayerUrl() {
    final room = Uri.encodeComponent(
      _roomController.text.trim().isEmpty
          ? 'cinenest'
          : _roomController.text.trim(),
    );
    final base = Request.dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base/pc-player?room=$room';
  }

  void _playOnPhone(LocalVideo video) {
    Get.toNamed(
      Routes.sourcePicker,
      arguments: {
        'title': video.title,
        'url': _absoluteUrl(video.streamUrl),
        'sourceName': 'PC local - ${video.filename}',
      },
    );
  }

  void _castToPc(LocalVideo video) {
    Get.toNamed(
      Routes.pcRemote,
      arguments: {
        'room': _roomController.text.trim().isEmpty
            ? 'cinenest'
            : _roomController.text.trim(),
        'video': video.toJson(),
        'url': _absoluteUrl(video.streamUrl),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PC local videos'),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            onPressed: _loading ? null : () => _loadVideos(rescan: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _roomController,
            decoration: const InputDecoration(
              labelText: 'Room ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.meeting_room_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'Open on PC browser: ${_pcPlayerUrl()}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _MessageCard(
              icon: Icons.error_outline_rounded,
              title: 'Load failed',
              message: _error!,
            )
          else if (_videos.isEmpty)
            const _MessageCard(
              icon: Icons.folder_open_rounded,
              title: 'No local videos',
              message:
                  r'Put mp4/mkv/mov/webm/m3u8/avi files into d:\FLutter\HarmonyOs\CineNest\LocalVideos, then tap Rescan.',
            )
          else
            ..._videos.map(
              (video) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.relativePath} · ${_formatBytes(video.size)}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _playOnPhone(video),
                            icon: const Icon(Icons.phone_android_rounded),
                            label: const Text('Play on phone'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _castToPc(video),
                            icon: const Icon(Icons.cast_rounded),
                            label: const Text('Cast to PC'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
