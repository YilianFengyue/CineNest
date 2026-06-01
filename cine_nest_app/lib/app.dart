import 'package:cine_nest/common/widgets/custom_toast.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:cine_nest/utils/theme_utils.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// 应用根组件（移植自 PiliPlus 的 main.dart MyApp，裁剪桌面/缩放细节）。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String appName = 'CineNest';

  @override
  Widget build(BuildContext context) {
    // 动态色（Material You）：可用则取系统配色，否则用 Pref 中的品牌种子色。
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useDynamic = Pref.dynamicColor &&
            lightDynamic != null &&
            darkDynamic != null;
        final seed = Pref.seedColor;

        final light = ThemeUtils.lightTheme = ThemeUtils.getThemeData(
          colorScheme: useDynamic
              ? lightDynamic
              : ColorScheme.fromSeed(seedColor: seed),
          isDynamic: useDynamic,
        );
        final dark = ThemeUtils.darkTheme = ThemeUtils.getThemeData(
          isDark: true,
          colorScheme: useDynamic
              ? darkDynamic
              : ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                ),
          isDynamic: useDynamic,
        );

        return GetMaterialApp(
          title: appName,
          theme: light,
          darkTheme: dark,
          themeMode: ThemeUtils.themeMode = Pref.themeMode,
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          locale: const Locale('zh', 'CN'),
          fallbackLocale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          initialRoute: Routes.home,
          getPages: AppPages.getPages,
          builder: FlutterSmartDialog.init(
            toastBuilder: (msg) => CustomToast(msg: msg),
            loadingBuilder: (msg) => LoadingWidget(msg: msg),
          ),
          navigatorObservers: [FlutterSmartDialog.observer],
        );
      },
    );
  }
}
