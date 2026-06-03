import 'dart:io';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_ws_service.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// 自定义输入区（成员 C · F9）。
///
/// 顶行：模型选择器（写死展示，后端待接 model 字段）。
/// 主行：附件按钮（图片/文件，多模态上传待后端支持）+ 多行输入框 + 发送。
///
/// 必须放进 [Positioned] 并把自身高度写回 [ComposerHeightNotifier]，
/// 否则消息列表底部会被输入框遮住（镜像 flutter_chat_ui 默认 Composer 的做法）。
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key});

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _key = GlobalKey();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _hasText = ValueNotifier<bool>(false);

  // 已选图片（本地路径），发送前在输入框上方预览。
  String? _imagePath;
  String? _imageName;

  ChatController get c => ChatController.to;

  @override
  void initState() {
    super.initState();
    _textController.addListener(
      () => _hasText.value = _textController.text.trim().isNotEmpty,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _hasText.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final bottomSafe = MediaQuery.of(context).padding.bottom;
      context.read<ComposerHeightNotifier>().setHeight(
        box.size.height - bottomSafe,
      );
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    final imagePath = _imagePath;
    if ((text.isEmpty && imagePath == null) || c.responding.value) return;
    _textController.clear();
    _hasText.value = false;

    List<Map<String, dynamic>>? attachments;
    if (imagePath != null) {
      setState(() {
        _imagePath = null;
        _imageName = null;
      });
      await c.sendImage(imagePath); // 本地气泡先展示
      final asset = await _uploadImage(imagePath); // 上传供 Agent 多模态识别
      if (asset != null) attachments = [asset];
    }

    if (text.isNotEmpty) {
      await c.send(text, attachments: attachments);
    } else if (attachments != null) {
      await c.send('请看这张图片', attachments: attachments);
    }
  }

  /// 上传图片到后端，返回可挂到消息的附件描述；失败返回 null（不阻断发送）。
  Future<Map<String, dynamic>?> _uploadImage(String path) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: path.split('/').last),
      });
      final res = await Request().post(ApiConstants.uploads, data: form);
      if (res.statusCode == 200 && res.data is Map) {
        final m = (res.data as Map).cast<String, dynamic>();
        return {
          'asset_id': m['asset_id'],
          'type': 'image',
          'mime': m['mime'] ?? 'image/png',
          'filename': m['filename'] ?? 'image.png',
        };
      }
    } catch (e) {
      logger.w('图片上传失败: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // 测量随每帧布局变化（多行输入展开时）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: _key,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(8, 6, 8, 8 + bottomSafe),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModelSelectorRow(),
            if (_imagePath != null) _attachmentPreview(cs),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '添加图片 / 文件',
                  onPressed: _pickAttachment,
                  icon: Icon(Icons.add_circle_outline, color: cs.onSurfaceVariant),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: '和 CineNest 聊聊你想看的电影…',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 4),
                _SendButton(
                  hasText: _hasText,
                  hasAttachment: _imagePath != null,
                  responding: c.responding,
                  onSend: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 已选图片的预览条（缩略图 + 文件名 + 移除）。
  Widget _attachmentPreview(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imagePath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.image_outlined, size: 18, color: cs.outline),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  _imageName ?? '图片',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() {
                  _imagePath = null;
                  _imageName = null;
                }),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选择图片 / 文件。当前后端 Agent 仅支持文本，先做完整选择交互并提示。
  Future<void> _pickAttachment() async {
    final cs = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('选择文件'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      if (choice == 'file') {
        // 文件（非图片）暂不预览：后端 Agent 多模态待支持，先提示。
        final res = await FilePicker.platform.pickFiles();
        final name = res?.files.single.name;
        if (mounted && name != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已选择文件「$name」，多模态上传待后端支持')),
          );
        }
      } else {
        final img = await ImagePicker().pickImage(
          source: choice == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        if (mounted && img != null) {
          // TODO(C→Codex): 后端 Agent 接多模态后，把图片随 message 上传给模型。
          setState(() {
            _imagePath = img.path;
            _imageName = img.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择失败，请重试')),
        );
      }
    }
  }
}

/// 模型选择行（写死展示）。
class _ModelSelectorRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = ChatController.to;
    return Align(
      alignment: Alignment.centerLeft,
      child: Obx(() {
        final list = c.models;
        final current = list.firstWhere(
          (m) => m.id == c.modelId.value,
          orElse: () => list.isNotEmpty ? list.first : kChatModels.first,
        );
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _pickModel(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 15, color: cs.primary),
                const SizedBox(width: 5),
                Text(
                  current.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _pickModel(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final c = ChatController.to;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择模型',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            for (final m in c.models)
              Obx(() {
                final selected = c.modelId.value == m.id;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: Text(m.label),
                  subtitle: Text(m.hint),
                  onTap: () {
                    c.setModel(m.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// 发送按钮：有文本且非应答中才可点。
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.hasText,
    required this.hasAttachment,
    required this.responding,
    required this.onSend,
  });

  final ValueNotifier<bool> hasText;
  final bool hasAttachment;
  final RxBool responding;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final busy = responding.value;
      return ValueListenableBuilder<bool>(
        valueListenable: hasText,
        builder: (_, has, _) {
          final enabled = (has || hasAttachment) && !busy;
          return IconButton.filled(
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: enabled ? cs.primary : cs.surfaceContainerHighest,
              foregroundColor: enabled ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            icon: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          );
        },
      );
    });
  }
}
