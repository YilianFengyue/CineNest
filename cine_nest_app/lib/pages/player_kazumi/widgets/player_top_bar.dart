import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../../utils/storage_pref.dart';
import '../controller/player_controller.dart';
import 'danmaku_settings_panel.dart';
import 'player_settings_sheet.dart';

/// 播放器顶部控制栏。
///
/// - [compact] = true：内嵌模式（16:9 小屏），紧凑、不显示标题文本
/// - [compact] = false：全屏模式，显示标题
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.controller,
    this.title,
    this.onBack,
    this.onEnterPip,
    this.compact = false,
    this.onToggleFavorite,
    this.isFavorite = false,
  });

  final KazumiPlayerController controller;
  final String? title;
  final VoidCallback? onBack;
  final Future<void> Function()? onEnterPip;
  final bool compact;
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;

  void _showMore(BuildContext context) {
    controller.showControlsTemporarily();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSettingsSheet(controller: controller),
    );
  }

  Widget _skip80Icon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              '80',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // inline 模式视频是 AspectRatio 框、不在屏顶，外层用 SafeArea 让出状态栏。
    // 这里 topPad 只在全屏模式吃 MediaQuery padding。
    final double topPad =
        compact ? 0 : MediaQuery.paddingOf(context).top;
    final double barHeight = compact ? 36 : kToolbarHeight;
    final double iconBox = compact ? 32 : 36;
    final double iconSize = compact ? 19 : 21;

    final iconButtons = <Widget>[
      // 弹幕开关
      Obx(
        () {
          final on = controller.danmakuVisible.value;
          final count = controller.danmakuCount.value;
          final hasKey = Pref.hasDanmakuCredentials;
          return IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
            icon: Icon(
              on ? Icons.subtitles : Icons.subtitles_off_outlined,
              color: Colors.white,
              size: iconSize,
            ),
            tooltip: on
                ? '弹幕 开${count > 0 ? ' ($count)' : ''}'
                : '弹幕 关',
            onPressed: () {
              if (!hasKey) {
                SmartDialog.showToast('请先在 设置→弹幕设置 中配置弹幕源');
                return;
              }
              controller.toggleDanmaku();
            },
          );
        },
      ),
      // 弹幕设置
      IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
        icon: Icon(Icons.tune, color: Colors.white, size: iconSize),
        tooltip: '弹幕设置',
        onPressed: () {
          controller.showControlsTemporarily();
          DanmakuSettingsPanel.show(context, controller);
        },
      ),
      // 快进 80 秒（跳片头）
      IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
        icon: _skip80Icon(),
        tooltip: '快进 80 秒',
        onPressed: () => controller.skipBy(const Duration(seconds: 80)),
      ),
      // 小窗
      IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
        icon: const Icon(
          Icons.picture_in_picture_alt,
          color: Colors.white,
          size: 20,
        ),
        tooltip: '小窗',
        onPressed: onEnterPip == null
            ? null
            : () async {
                controller.showControlsTemporarily();
                await onEnterPip!();
              },
      ),
      // 收藏
      if (onToggleFavorite != null)
        IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.redAccent : Colors.white,
            size: iconSize,
          ),
          tooltip: '收藏',
          onPressed: onToggleFavorite,
        ),
      // 锁屏
      Obx(
        () => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
          icon: Icon(
            controller.lockPanel.value ? Icons.lock : Icons.lock_open,
            color: Colors.white,
            size: iconSize,
          ),
          tooltip: controller.lockPanel.value ? '解锁' : '锁定',
          onPressed: controller.toggleLock,
        ),
      ),
      // 更多
      IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: iconBox, height: iconBox),
        icon: Icon(Icons.more_vert, color: Colors.white, size: iconSize),
        tooltip: '设置',
        onPressed: () => _showMore(context),
      ),
    ];

    return Container(
      padding: EdgeInsets.only(top: topPad, left: 4, right: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SizedBox(
        height: barHeight,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: compact ? 36 : 40,
                height: 40,
              ),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            if (!compact && (title?.isNotEmpty ?? false))
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            ...iconButtons,
          ],
        ),
      ),
    );
  }
}
