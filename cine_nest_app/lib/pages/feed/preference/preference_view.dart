import 'package:cine_nest/pages/player/views/connection_settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'preference_controller.dart';

class PreferencePage extends GetView<PreferenceController> {
  const PreferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PreferenceController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Obx(
            () => TextButton(
              onPressed: controller.isSaving.value
                  ? null
                  : () => controller.savePreferences(),
              child: controller.isSaving.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader(
              context,
              'Liked genres',
              Icons.favorite,
              Colors.redAccent,
            ),
            const SizedBox(height: 12),
            _buildGenreChips(context, isLike: true),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              'Disliked genres',
              Icons.do_not_disturb_on,
              Colors.grey,
            ),
            const SizedBox(height: 12),
            _buildGenreChips(context, isLike: false),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              'Extra requirements',
              Icons.edit_note,
              colorScheme.primary,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.freeTextController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'For example: puzzle movies, no horror, more 1990s classics...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your preferences will affect the AI recommendation logic.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 48),
            const ConnectionSettingsPanel(),
          ],
        );
      }),
    );
  }

  Widget _buildSectionHeader(
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGenreChips(BuildContext context, {required bool isLike}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: controller.allGenres.map((genre) {
        final isSelected = isLike
            ? controller.likedGenres.contains(genre)
            : controller.dislikedGenres.contains(genre);
        final colorScheme = Theme.of(context).colorScheme;

        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (_) => isLike
              ? controller.toggleLike(genre)
              : controller.toggleDislike(genre),
          selectedColor: isLike
              ? Colors.redAccent.withAlpha(50)
              : colorScheme.outline.withAlpha(50),
          checkmarkColor: isLike ? Colors.redAccent : colorScheme.outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }
}
