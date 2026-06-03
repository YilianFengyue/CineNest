abstract final class ApiConstants {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  static const String health = '/api/health';

  // Member B
  static const String feed = '/api/feed';
  static const String discovery = '/api/discovery';
  static String movieDetail(Object id) => '/api/movie/$id';
  static const String preferences = '/api/preferences';
  static const String feedback = '/api/feedback';

  // Member A
  static const String sourcesSearch = '/api/sources/search';
  static const String sourcesParse = '/api/sources/parse';
  static const String bilibiliSearch = '/api/bilibili/search';

  // Member C
  static String poster(Object movieId) => '/api/poster/$movieId';
  static const String news = '/api/news';
  static const String wsChat = '/ws/chat';
}
