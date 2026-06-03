import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_ws_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
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

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty || c.responding.value) return;
    c.send(text);
    _textController.clear();
    _hasText.value = false;
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

    String? picked;
    try {
      if (choice == 'file') {
        final res = await FilePicker.platform.pickFiles();
        picked = res?.files.single.name;
      } else {
        final img = await ImagePicker().pickImage(
          source: choice == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        picked = img?.name;
      }
    } catch (e) {
      picked = null;
    }
    if (!mounted || picked == null) return;
    // TODO(C→Codex): 后端 Agent 接入多模态后，把附件随 message 一并上传。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选择「$picked」，多模态上传待后端支持')),
    );
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
        final current = kChatModels.firstWhere(
          (m) => m.id == c.modelId.value,
          orElse: () => kChatModels.first,
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
            for (final m in kChatModels)
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
    required this.responding,
    required this.onSend,
  });

  final ValueNotifier<bool> hasText;
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
          final enabled = has && !busy;
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
