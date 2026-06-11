class TasteScore {
  const TasteScore({required this.name, required this.score});

  final String name;
  final double score;

  factory TasteScore.fromJson(Map<String, dynamic> json) => TasteScore(
    name: json['name']?.toString() ?? '',
    score: json['score'] is num
        ? (json['score'] as num).toDouble()
        : double.tryParse(json['score']?.toString() ?? '') ?? 0,
  );
}

class TasteDna {
  const TasteDna({
    required this.topGenres,
    required this.avoidGenres,
    required this.moodTags,
    required this.eraTags,
    required this.summary,
    required this.confidence,
    required this.signature,
    this.avatarUrl,
  });

  final List<TasteScore> topGenres;
  final List<String> avoidGenres;
  final List<String> moodTags;
  final List<String> eraTags;
  final String summary;
  final double confidence;
  final String? avatarUrl;
  final String signature;

  factory TasteDna.fromJson(Map<String, dynamic> json) => TasteDna(
    topGenres: _scoreList(json['top_genres']),
    avoidGenres: _stringList(json['avoid_genres']),
    moodTags: _stringList(json['mood_tags']),
    eraTags: _stringList(json['era_tags']),
    summary: json['summary']?.toString() ?? '',
    confidence: json['confidence'] is num
        ? (json['confidence'] as num).toDouble()
        : double.tryParse(json['confidence']?.toString() ?? '') ?? 0,
    avatarUrl: json['avatar_url']?.toString(),
    signature: json['signature']?.toString() ?? '',
  );

  static List<TasteScore> _scoreList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => TasteScore.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}

class TasteAvatarResponse {
  const TasteAvatarResponse({
    required this.avatarUrl,
    required this.prompt,
    required this.cached,
    required this.signature,
    this.warning,
  });

  final String avatarUrl;
  final String prompt;
  final bool cached;
  final String signature;
  final String? warning;

  factory TasteAvatarResponse.fromJson(Map<String, dynamic> json) =>
      TasteAvatarResponse(
        avatarUrl: json['avatar_url']?.toString() ?? '',
        prompt: json['prompt']?.toString() ?? '',
        cached: json['cached'] == true,
        signature: json['signature']?.toString() ?? '',
        warning: json['warning']?.toString(),
      );
}
