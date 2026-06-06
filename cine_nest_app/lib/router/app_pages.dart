import 'package:cine_nest/pages/creative/favorites_page.dart';
import 'package:cine_nest/pages/creative/news/news_tasks_page.dart';
import 'package:cine_nest/pages/creative/poster/poster_page.dart';
import 'package:cine_nest/pages/feed/collection/collection_view.dart';
import 'package:cine_nest/pages/feed/detail/detail_view.dart';
import 'package:cine_nest/pages/feed/feed_view.dart';
import 'package:cine_nest/pages/feed/history/history_view.dart';
import 'package:cine_nest/pages/feed/preference/preference_view.dart';
import 'package:cine_nest/pages/main/main_app.dart';
import 'package:cine_nest/pages/player/views/source_picker_page.dart';
import 'package:cine_nest/pages/player/views/webview_player_page.dart';
import 'package:cine_nest/pages/player_kazumi/test_page/local_player_test_page.dart';
import 'package:get/get.dart';

part 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage> getPages = [
    GetPage(name: Routes.home, page: () => const MainApp()),

    // Member B
    GetPage(name: Routes.feed, page: () => const FeedPage()),
    GetPage(name: Routes.movieDetail, page: () => const MovieDetailPage()),
    GetPage(name: Routes.preference, page: () => const PreferencePage()),
    GetPage(name: Routes.history, page: () => const HistoryPage()),
    GetPage(name: Routes.collection, page: () => const CollectionPage()),

    // Member A
    GetPage(name: Routes.sourcePicker, page: () => const SourcePickerPage()),
    GetPage(name: Routes.webviewPlayer, page: () => const WebViewPlayerPage()),
    GetPage(
      name: Routes.kazumiPlayerTest,
      page: () => const LocalPlayerTestPage(),
    ),

    // Member C
    GetPage(name: Routes.creativePoster, page: () => const PosterPage()),
    GetPage(name: Routes.creativeFavorites, page: () => const FavoritesPage()),
    GetPage(name: Routes.creativeNewsTasks, page: () => const NewsTasksPage()),
  ];
}
