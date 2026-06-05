import 'package:cine_nest/pages/player/views/source_debug_panel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SourcePickerPage extends StatelessWidget {
  const SourcePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final title = args is Map ? args['title']?.toString() : null;
    final movieName = title == null || title.trim().isEmpty
        ? 'The Shawshank Redemption'
        : title.trim();

    return Scaffold(
      appBar: AppBar(title: Text('Play $movieName')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SourceDebugPanel(initialMovieName: movieName, autoSearch: true),
      ),
    );
  }
}
