import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 统一处理 MicroDesign 白名单动作（对话卡 / 海报页 / 资讯卡共用）。
///
///  · `openPoster` / `openResourcePoster` → 跳 F8 互动海报详情页。
///  · `resolveAndPlay` → 调 `/api/play/resolve` 解析统一播放描述。
///    A 的播放器路由就绪后改为 `Get.toNamed(Routes.player, ...)`；
///    当前先弹出解析结果（地址可复制），保证链路可验收。
Future<void> handleCreativeAction(BuildContext context, MicroAction action) async {
  switch (action.type) {
    case 'openPoster':
    case 'openResourcePoster':
      Get.toNamed(Routes.creativePoster, arguments: action.data);
      break;
    case 'resolveAndPlay':
      await _resolveAndPlay(context, action);
      break;
    default:
      break;
  }
}

Future<void> _resolveAndPlay(BuildContext context, MicroAction action) async {
  final provider = action.str('provider_id');
  final remote = action.str('remote_id');
  final messenger = ScaffoldMessenger.of(context);
  if (provider.isEmpty || remote.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('缺少播放参数')));
    return;
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('正在解析播放地址…'), duration: Duration(seconds: 1)),
  );
  Map<String, dynamic>? desc;
  try {
    final res = await Request().get(
      ApiConstants.playResolve,
      queryParameters: {'provider_id': provider, 'remote_id': remote},
    );
    if (res.statusCode == 200 && res.data is Map) {
      desc = (res.data as Map).cast<String, dynamic>();
    }
  } catch (e) {
    logger.w('播放解析失败: $e');
  }
  if (desc == null) {
    messenger.showSnackBar(const SnackBar(content: Text('解析失败，资源可能已失效')));
    return;
  }
  final playUrl = desc['play_url'] as String? ?? '';
  if (playUrl.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('未拿到可播放地址')));
    return;
  }
  // TODO(C↔A): A 的 /player 就绪后改为 Get.toNamed(Routes.player, arguments: desc)。
  if (!context.mounted) return;
  _showResolvedSheet(context, desc, playUrl);
}

void _showResolvedSheet(
  BuildContext context,
  Map<String, dynamic> desc,
  String playUrl,
) {
  final cs = Theme.of(context).colorScheme;
  final title = desc['title'] as String? ?? '播放地址';
  final line = [desc['line_name'], desc['episode_name']]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' · ');
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                ),
              ],
            ),
            if (line.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(line, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                playUrl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '播放器由成员 A 接入（/player）；当前可复制地址验证。',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: playUrl));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制播放地址')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制地址'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
