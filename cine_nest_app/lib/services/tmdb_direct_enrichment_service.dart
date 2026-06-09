import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';
import 'package:cine_nest/modules/media_aggregator/services/tmdb_enrichment_service.dart';
import 'package:cine_nest/services/tmdb_direct_service.dart';

class TmdbDirectEnrichmentService extends TmdbEnrichmentService {
  TmdbDirectEnrichmentService({TmdbDirectService? tmdb})
      : _tmdb = tmdb ?? TmdbDirectService();

  final TmdbDirectService _tmdb;

  @override
  Future<TmdbEnrichment?> enrich({
    required String title,
    String? year,
    String mediaKind = 'movie',
  }) async {
    try {
      final mediaType = mediaKind == 'tv' ? 'tv' : 'movie';
      final results = await _tmdb
          .search(title, mediaType: mediaType, year: year)
          .timeout(const Duration(seconds: 4));
      if (results.isEmpty) return null;

      final best = _pickBest(results, title, year);
      return TmdbEnrichment(
        tmdbId: best.id,
        title: best.title,
        originalTitle: best.originalTitle,
        posterUrl: best.poster(),
        backdropUrl: best.backdrop(),
        overview: best.overview,
        rating: best.voteAverage,
        genres: _genreNames(best.genreIds),
      );
    } catch (_) {
      return null;
    }
  }

  TmdbMediaItem _pickBest(
      List<TmdbMediaItem> items, String title, String? year) {
    final norm = _normalize(title);
    for (final item in items) {
      if (_normalize(item.title) == norm || _normalize(item.originalTitle) == norm) {
        if (year == null || year.isEmpty || item.year == year) return item;
      }
    }
    for (final item in items) {
      if (_normalize(item.title) == norm || _normalize(item.originalTitle) == norm) {
        return item;
      }
    }
    return items.first;
  }

  String _normalize(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[\s\-_:：·.，,。！!？?《》【】\[\]()（）]+'), '');

  static const _genreMap = <int, String>{
    28: '动作', 12: '冒险', 16: '动画', 35: '喜剧', 80: '犯罪',
    99: '纪录', 18: '剧情', 10751: '家庭', 14: '奇幻', 36: '历史',
    27: '恐怖', 10402: '音乐', 9648: '悬疑', 10749: '爱情', 878: '科幻',
    10770: '电视电影', 53: '惊悚', 10752: '战争', 37: '西部',
    10759: '动作冒险', 10762: '儿童', 10763: '新闻', 10764: '真人秀',
    10765: '科幻奇幻', 10766: '肥皂剧', 10767: '脱口秀', 10768: '战争政治',
  };

  List<String> _genreNames(List<int> ids) =>
      ids.map((id) => _genreMap[id]).whereType<String>().toList();
}
