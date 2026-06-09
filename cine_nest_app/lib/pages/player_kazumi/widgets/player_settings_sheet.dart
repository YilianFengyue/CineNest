import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

import '../controller/player_controller.dart';

/// 底部设置面板：倍速 / 比例 / 音轨 / 字幕轨。
class PlayerSettingsSheet extends StatelessWidget {
  const PlayerSettingsSheet({super.key, required this.controller});

  final KazumiPlayerController controller;

  static const _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];
  static const _aspectLabels = ['原始', '填充裁剪', '拉伸'];
  static const _shaderLabels = ['关闭', '效率优先', '质量优先'];
  static const _shaderTypes = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: '倍速'),
                Tab(text: '比例'),
                Tab(text: '超分'),
                Tab(text: '音轨'),
                Tab(text: '字幕'),
              ],
            ),
            Flexible(
              child: TabBarView(
                children: [
                  _buildSpeed(context),
                  _buildAspect(context),
                  _buildShader(context),
                  _buildAudioTracks(context),
                  _buildSubtitleTracks(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeed(BuildContext context) {
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(12),
        children: _speedPresets.map((s) {
          final selected = (controller.speed.value - s).abs() < 0.01;
          return ListTile(
            dense: true,
            title: Text(s == s.toInt() ? '${s.toInt()}x' : '${s}x'),
            trailing: selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.setSpeed(s);
              Navigator.maybePop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAspect(BuildContext context) {
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(12),
        children: List.generate(3, (i) {
          final type = i + 1;
          final selected = controller.aspectRatioType.value == type;
          return ListTile(
            dense: true,
            title: Text(_aspectLabels[i]),
            trailing: selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.aspectRatioType.value = type;
              Navigator.maybePop(context);
            },
          );
        }),
      ),
    );
  }

  Widget _buildShader(BuildContext context) {
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(12),
        children: List.generate(3, (i) {
          final type = _shaderTypes[i];
          final selected = controller.superResolution.value == type;
          return ListTile(
            dense: true,
            title: Text(_shaderLabels[i]),
            subtitle: i == 0
                ? null
                : Text(
                    i == 1 ? '低功耗，适合中低端设备' : '高画质，需要较好的 GPU',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            trailing: selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.setShader(type);
              Navigator.maybePop(context);
            },
          );
        }),
      ),
    );
  }

  Widget _buildAudioTracks(BuildContext context) {
    final tracks = controller.player.state.tracks.audio;
    final current = controller.player.state.track.audio;
    if (tracks.isEmpty) {
      return const Center(child: Text('无音轨信息'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: tracks.map((t) {
        final selected = t == current;
        return ListTile(
          dense: true,
          title: Text(_audioTrackLabel(t)),
          trailing: selected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            controller.player.setAudioTrack(t);
            Navigator.maybePop(context);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSubtitleTracks(BuildContext context) {
    final tracks = controller.player.state.tracks.subtitle;
    final current = controller.player.state.track.subtitle;
    if (tracks.isEmpty) {
      return const Center(child: Text('无字幕轨信息'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: tracks.map((t) {
        final selected = t == current;
        return ListTile(
          dense: true,
          title: Text(_subtitleTrackLabel(t)),
          trailing: selected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            controller.player.setSubtitleTrack(t);
            Navigator.maybePop(context);
          },
        );
      }).toList(),
    );
  }

  String _audioTrackLabel(AudioTrack t) {
    final lang = (t.language ?? '').isNotEmpty ? t.language : '';
    final title = (t.title ?? '').isNotEmpty ? t.title : '';
    if (title!.isNotEmpty && lang!.isNotEmpty) return '$title · $lang';
    if (title.isNotEmpty) return title;
    if (lang!.isNotEmpty) return lang;
    return 'Track ${t.id}';
  }

  String _subtitleTrackLabel(SubtitleTrack t) {
    final lang = (t.language ?? '').isNotEmpty ? t.language : '';
    final title = (t.title ?? '').isNotEmpty ? t.title : '';
    if (title!.isNotEmpty && lang!.isNotEmpty) return '$title · $lang';
    if (title.isNotEmpty) return title;
    if (lang!.isNotEmpty) return lang;
    return 'Track ${t.id}';
  }
}
