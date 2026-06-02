import 'package:cine_nest/pages/main/main_app.dart';
import 'package:cine_nest/pages/player/views/player_page.dart';
import 'package:cine_nest/pages/player/views/webview_player_page.dart';
import 'package:get/get.dart';

part 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage> getPages = [
    GetPage(name: Routes.home, page: () => const MainApp()),
    GetPage(name: Routes.player, page: () => const PlayerPage()),
    GetPage(name: Routes.webviewPlayer, page: () => const WebViewPlayerPage()),
  ];
}
