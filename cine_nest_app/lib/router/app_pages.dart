import 'package:cine_nest/pages/feed/detail/detail_view.dart';
import 'package:cine_nest/pages/feed/feed_view.dart';
import 'package:cine_nest/pages/feed/preference/preference_view.dart';
import 'package:cine_nest/pages/main/main_app.dart';
import 'package:cine_nest/pages/player/views/player_page.dart';
import 'package:cine_nest/pages/player/views/source_picker_page.dart';
import 'package:cine_nest/pages/player/views/webview_player_page.dart';
import 'package:get/get.dart';

part 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage> getPages = [
    GetPage(name: Routes.home, page: () => const MainApp()),
    GetPage(name: '/feed', page: () => const FeedPage()),
    GetPage(name: Routes.movieDetail, page: () => const MovieDetailPage()),
    GetPage(name: Routes.preference, page: () => const PreferencePage()),
    GetPage(name: Routes.player, page: () => const PlayerPage()),
    GetPage(name: Routes.sourcePicker, page: () => const SourcePickerPage()),
    GetPage(name: Routes.webviewPlayer, page: () => const WebViewPlayerPage()),
  ];
}
