import '../models/media_models.dart';

class SourceRanker {
  List<AggregatorSearchResult> rank(
    String keyword,
    Iterable<AggregatorSearchResult> results,
  ) {
    final normalizedKeyword = normalizeTitle(keyword);
    final ranked = results.toList()
      ..sort((a, b) {
        final scoreA = _score(normalizedKeyword, a);
        final scoreB = _score(normalizedKeyword, b);
        final byScore = scoreB.compareTo(scoreA);
        if (byScore != 0) return byScore;
        final byEpisodeCount = b.episodeCount.compareTo(a.episodeCount);
        if (byEpisodeCount != 0) return byEpisodeCount;
        return a.title.compareTo(b.title);
      });
    return ranked;
  }

  int _score(String normalizedKeyword, AggregatorSearchResult item) {
    final title = normalizeTitle(item.title);
    var score = 0;
    if (title == normalizedKeyword) {
      score += 100;
    } else if (title.contains(normalizedKeyword) ||
        normalizedKeyword.contains(title)) {
      score += 55;
    }
    if (item.year != null && item.year!.isNotEmpty) score += 8;
    if (item.hasPlayableDirectUrl) score += 35;
    if (item.episodeCount > 1) score += 10;
    if ((item.remarks ?? '').contains('更新')) score += 4;
    score -= item.health?.rankPenalty ?? 12;
    if (_looksLowQuality(item)) score -= 35;
    return score;
  }

  bool _looksLowQuality(AggregatorSearchResult item) {
    final haystack =
        '${item.title} ${item.category ?? ''} ${item.typeName ?? ''}';
    const words = ['伦理', '写真', '福利', '解说', '预告', '花絮'];
    return words.any(haystack.contains);
  }

  String normalizeTitle(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[\s\-_:：·.，,。！!？?《》【】\[\]()（）]+'),
      '',
    );
  }
}
