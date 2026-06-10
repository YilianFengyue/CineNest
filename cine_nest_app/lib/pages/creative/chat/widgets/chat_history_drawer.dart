import 'package:cine_nest/pages/creative/chat/chat_controller.dart';
import 'package:cine_nest/pages/creative/chat/services/chat_store.dart';
import 'package:cine_nest/pages/main/main_app.dart';
import 'package:flutter/material.dart';

/// 对话侧边历史抽屉（成员 C · F9）—— 仿 Gemini 的汉堡抽屉。
///
/// 取代原先那个底部 sheet：
///   · 顶部「新对话」入口
///   · 中部历史会话列表（Material You tonal 选中态 + 涟漪，点切换 / 长按删除）
///   · 底部目的地（首页 / 资讯 / 设置）—— 对话页隐藏了底部导航，这里补回切 Tab 入口
class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  ChatController get _c => ChatController.to;

  void _newChat() {
    _c.newSession();
    Navigator.of(context).pop();
  }

  void _open(String id) {
    _c.loadSession(id);
    Navigator.of(context).pop();
  }

  Future<void> _delete(String id) async {
    await _c.deleteSession(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sessions = ChatStore.sessions();
    final activeId = _c.threadId;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── 头部品牌 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'CineNest 助手',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // ── 新对话 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('新对话'),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '历史对话',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // ── 历史列表 ──
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(
                        '还没有历史对话',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: sessions.length,
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        final selected = s.id == activeId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: cs.secondaryContainer,
                            selectedColor: cs.onSecondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            leading: Icon(
                              selected
                                  ? Icons.chat_bubble
                                  : Icons.chat_bubble_outline,
                              size: 20,
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${s.messageCount} 条消息'),
                            trailing: IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _delete(s.id),
                            ),
                            onTap: () => _open(s.id),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // ── 底部目的地（对话页无底部导航，这里补切 Tab）──
            _DestTile(icon: Icons.movie_outlined, label: '首页', tab: 0),
            _DestTile(icon: Icons.article_outlined, label: '资讯', tab: 2),
            _DestTile(icon: Icons.settings_outlined, label: '设置', tab: 3),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 抽屉底部的"切到其它 Tab"入口。
class _DestTile extends StatelessWidget {
  const _DestTile({required this.icon, required this.label, required this.tab});

  final IconData icon;
  final String label;
  final int tab;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      visualDensity: VisualDensity.compact,
      onTap: () {
        Navigator.of(context).pop();
        MainNavController.to.go(tab);
      },
    );
  }
}
