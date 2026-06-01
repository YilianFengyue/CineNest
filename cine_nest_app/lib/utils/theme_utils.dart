import 'package:cine_nest/utils/extension/theme_ext.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/material.dart';

/// 主题系统（移植自 PiliPlus 的 `lib/utils/theme_utils.dart`）。
///
/// 保留母版的 Material 3 组件级主题定制（AppBar/Card/Dialog/BottomSheet…）与
/// 明暗双主题缓存；色彩方案改用 Flutter 内置 [ColorScheme.fromSeed]（去掉
/// flex_seed_scheme 第三方依赖），动态色仍由 dynamic_color 在 main 中注入。
abstract final class ThemeUtils {
  static late ThemeData lightTheme;
  static late ThemeData darkTheme;
  static late ThemeMode themeMode;

  static ThemeData get theme {
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    return isDark ? darkTheme : lightTheme;
  }

  static bool get isDarkMode => theme.isDark;

  static ThemeData getThemeData({
    required ColorScheme colorScheme,
    required bool isDynamic,
    bool isDark = false,
  }) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        titleTextStyle: TextStyle(
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
      ),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: colorScheme.primary,
        backgroundColor: colorScheme.secondaryContainer,
        closeIconColor: colorScheme.secondary,
        contentTextStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        elevation: 20,
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        surfaceTintColor: isDynamic || isDark
            ? colorScheme.onSurfaceVariant
            : null,
        shadowColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(fontSize: 18, color: colorScheme.onSurface),
        backgroundColor: colorScheme.surface,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
