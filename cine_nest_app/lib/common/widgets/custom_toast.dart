import 'package:flutter/material.dart';

/// 全局 Toast 样式（移植自 PiliPlus，配合 flutter_smart_dialog）。
class CustomToast extends StatelessWidget {
  const CustomToast({super.key, required this.msg});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 30,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(
        msg,
        style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// 全局 Loading 样式（移植自 PiliPlus）。
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, required this.msg});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: theme.dialogTheme.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      child: Column(
        spacing: 20,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(onSurfaceVariant),
          ),
          Text(msg, style: TextStyle(color: onSurfaceVariant)),
        ],
      ),
    );
  }
}
