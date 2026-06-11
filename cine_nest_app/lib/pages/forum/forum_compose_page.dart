import 'package:cine_nest/pages/forum/forum_api.dart';
import 'package:cine_nest/pages/forum/forum_identity.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForumComposePage extends StatefulWidget {
  const ForumComposePage({super.key});

  @override
  State<ForumComposePage> createState() => _ForumComposePageState();
}

class _ForumComposePageState extends State<ForumComposePage> {
  final _api = const ForumApi();
  final _nicknameController = TextEditingController(
    text: ForumIdentity.nickname,
  );
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _nicknameController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (nickname.isEmpty || title.isEmpty || content.isEmpty) {
      setState(() => _error = 'Nickname, title and content are required.');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await ForumIdentity.saveNickname(nickname);
      await _api.createPost(
        title: title,
        content: content,
        authorName: nickname,
        clientId: ForumIdentity.clientId,
      );
      if (mounted) Get.back(result: true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New forum post'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submit,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nicknameController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLength: 2000,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Content',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _posting ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Publish post'),
          ),
        ],
      ),
    );
  }
}
