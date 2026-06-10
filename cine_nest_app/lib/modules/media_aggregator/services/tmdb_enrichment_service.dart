import '../../../../http/init.dart';
import '../models/media_models.dart';

class TmdbEnrichmentService {
  const TmdbEnrichmentService();

  static const String _catalogSearchPath = '/api/catalog/search';

  Future<TmdbEnrichment?> enrich({
    required String title,
    String? year,
    String mediaKind = 'movie',
  }) async {
    try {
      final response = await Request().get(
        _catalogSearchPath,
        queryParameters: {'query': title, 'media_kind': mediaKind, 'limit': 5},
      );
      final data = response.data;
      if (data is! Map) return null;
      final items = data['items'];
      if (items is! List || items.isEmpty) return null;
      final item = _pickBest(items.whereType<Map>(), title, year);
      if (item == null) return null;
      return _fromCatalog(Map<String, dynamic>.from(item));
    } catch (_) {
      return null;
    }
  }

  Map? _pickBest(Iterable<Map> items, String title, String? year) {
    final normalizedTitle = _normalize(title);
    Map? fallback;
    for (final item in items) {
      fallback ??= item;
      final itemTitle = _normalize('${item['title'] ?? ''}');
      final itemYear = '${item['year'] ?? ''}';
      if (itemTitle == normalizedTitle &&
          (year == null || year.isEmpty || itemYear == year)) {
        return item;
      }
    }
    return fallback;
  }

  TmdbEnrichment _fromCatalog(Map<String, dynamic> json) {
    return TmdbEnrichment(
      tmdbId: int.tryParse('${json['source_id'] ?? ''}'),
      title: json['title']?.toString(),
      originalTitle: json['original_title']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      backdropUrl: json['backdrop_url']?.toString(),
      overview: json['overview']?.toString(),
      rating: double.tryParse('${json['rating'] ?? ''}'),
      genres: (json['genres'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      cast: (json['cast'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[\s\-_:：·.，,。！!？?《》【】\[\]()（）]+'),
      '',
    );
  }
}
