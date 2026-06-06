import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/player_controller.dart';
import 'player_settings_sheet.dart';

/// 播放器顶部控制栏：返回 + 标题 + 锁屏 + 更多。
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.controller,
    this.title,
    this.onBack,
  });

  final KazumiPlayerController controller;
  final String? title;
  final VoidCallback? onBack;

  void _showMore(BuildContext context) {
    controller.showControlsTemporarily();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSettingsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 8,
        right: 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                title ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Obx(() => IconButton(
                  icon: Icon(
                    controller.lockPanel.value
                        ? Icons.lock
                        : Icons.lock_open,
                    color: Colors.white,
                  ),
                  tooltip: controller.lockPanel.value ? '解锁' : '锁定',
                  onPressed: controller.toggleLock,
                )),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: '设置',
              onPressed: () => _showMore(context),
            ),
          ],
        ),
      ),
    );
  }
}
