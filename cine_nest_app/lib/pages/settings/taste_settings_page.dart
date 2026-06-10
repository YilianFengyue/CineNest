import 'package:cine_nest/pages/feed/preference/preference_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 口味偏好子页（迁移自原 PreferencePage 的「喜好」部分）。
///
/// 原来这块和 PC 连接面板挤在同一个 Settings 页里；现在拆成独立子页，
/// 从设置页「口味偏好」入口进入。复用既有的 [PreferenceController]
/// （喜欢/不喜欢类型 + 自由文本 + 保存逻辑全部沿用）。
class TasteSettingsPage extends StatelessWidget {
  const TasteSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PreferenceController());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('口味偏好'),
        actions: [
          Obx(
            () => TextButton.icon(
              onPressed: controller.isSaving.value
                  ? null
                  : controller.savePreferences,
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _header(context, '喜欢的类型', Icons.favorite, cs.primary),
            const SizedBox(height: 12),
            _genreChips(context, controller, isLike: true),
            const SizedBox(height: 28),
            _header(
              context,
              '不喜欢的类型',
              Icons.do_not_disturb_on_outlined,
              cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            _genreChips(context, controller, isLike: false),
            const SizedBox(height: 28),
            _header(context, '补充要求', Icons.edit_note, cs.primary),
            const SizedBox(height: 12),
            TextField(
              controller: controller.freeTextController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '例如：烧脑反转、别推恐怖片、想看 90 年代经典…',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '你的偏好会作为 AI 推荐的输入依据。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _header(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _genreChips(
    BuildContext context,
    PreferenceController controller, {
    required bool isLike,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: controller.allGenres.map((genre) {
          final selected = isLike
              ? controller.likedGenres.contains(genre)
              : controller.dislikedGenres.contains(genre);
          return FilterChip(
            label: Text(genre),
            selected: selected,
            onSelected: (_) => isLike
                ? controller.toggleLike(genre)
                : controller.toggleDislike(genre),
            selectedColor: isLike
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
            checkmarkColor: isLike ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }).toList(),
      ),
    );
  }
}
