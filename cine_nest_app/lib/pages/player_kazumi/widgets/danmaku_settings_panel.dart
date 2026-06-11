import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/storage_pref.dart';
import '../controller/player_controller.dart';

/// PiliPlus 风格弹幕设置面板（从右上角弹出的底部 Sheet）。
class DanmakuSettingsPanel extends StatelessWidget {
  const DanmakuSettingsPanel({super.key, required this.controller});

  final KazumiPlayerController controller;

  static void show(BuildContext context, KazumiPlayerController c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DanmakuSettingsPanel(controller: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = controller;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
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
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('弹幕设置', style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: Obx(() => ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _sectionTitle(theme, '按类型屏蔽'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _TypeChip(
                      label: '滚动',
                      selected: c.danmakuHideScroll.value,
                      onChanged: (v) {
                        c.danmakuHideScroll.value = v;
                        Pref.setDanmakuHideScroll(v);
                      },
                    ),
                    _TypeChip(
                      label: '顶部',
                      selected: c.danmakuHideTop.value,
                      onChanged: (v) {
                        c.danmakuHideTop.value = v;
                        Pref.setDanmakuHideTop(v);
                      },
                    ),
                    _TypeChip(
                      label: '底部',
                      selected: c.danmakuHideBottom.value,
                      onChanged: (v) {
                        c.danmakuHideBottom.value = v;
                        Pref.setDanmakuHideBottom(v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _sectionTitle(theme, '其他'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _TypeChip(
                      label: '海量弹幕',
                      selected: c.danmakuMassive.value,
                      onChanged: (v) {
                        c.danmakuMassive.value = v;
                        Pref.setDanmakuMassive(v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SliderRow(
                  label: '显示区域',
                  value: c.danmakuArea.value,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  format: (v) => '${(v * 100).toStringAsFixed(0)}%',
                  onChanged: (v) {
                    c.danmakuArea.value = v;
                    Pref.setDanmakuArea(v);
                  },
                  onReset: () {
                    c.danmakuArea.value = 0.8;
                    Pref.setDanmakuArea(0.8);
                  },
                ),

                const SizedBox(height: 12),
                _SliderRow(
                  label: '不透明度',
                  value: c.danmakuOpacity.value,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  format: (v) => '${(v * 100).toStringAsFixed(0)}%',
                  onChanged: (v) {
                    c.danmakuOpacity.value = v;
                    Pref.setDanmakuOpacity(v);
                  },
                  onReset: () {
                    c.danmakuOpacity.value = 1.0;
                    Pref.setDanmakuOpacity(1.0);
                  },
                ),

                const SizedBox(height: 12),
                _SliderRow(
                  label: '字号',
                  value: c.danmakuFontScale.value,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  format: (v) => '${v.toStringAsFixed(1)}x',
                  onChanged: (v) {
                    c.danmakuFontScale.value = v;
                    Pref.setDanmakuFontScale(v);
                  },
                  onReset: () {
                    c.danmakuFontScale.value = 1.0;
                    Pref.setDanmakuFontScale(1.0);
                  },
                ),

                const SizedBox(height: 12),
                _SliderRow(
                  label: '弹幕速度',
                  value: c.danmakuDuration.value,
                  min: 4.0,
                  max: 14.0,
                  divisions: 10,
                  format: (v) => '${v.toStringAsFixed(0)}s',
                  onChanged: (v) {
                    c.danmakuDuration.value = v;
                    Pref.setDanmakuDuration(v);
                  },
                  onReset: () {
                    c.danmakuDuration.value = 8.0;
                    Pref.setDanmakuDuration(8.0);
                  },
                ),

                if (!Pref.hasDanmakuCredentials) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: cs.onErrorContainer, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '未配置弹幕源，请在 设置→弹幕设置 中配置',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label ${format(value)}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (onReset != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: onReset,
                tooltip: '重置',
              ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
