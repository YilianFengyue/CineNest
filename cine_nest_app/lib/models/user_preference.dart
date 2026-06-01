/// 用户偏好（共享契约，对应 F6 用户偏好与历史）。
///
/// 本地以 JSON Map 存入 GStorage.localCache，同时上报后端作为 Agent 推荐输入。
class UserPreference {
  final List<String> likedGenres; // 喜欢的类型
  final List<String> dislikedGenres; // 不喜欢的类型
  final String? freeText; // 自由文字口味描述（可选）

  const UserPreference({
    this.likedGenres = const [],
    this.dislikedGenres = const [],
    this.freeText,
  });

  factory UserPreference.fromJson(Map<String, dynamic> json) => UserPreference(
    likedGenres:
        (json['liked_genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    dislikedGenres:
        (json['disliked_genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    freeText: json['free_text'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'liked_genres': likedGenres,
    'disliked_genres': dislikedGenres,
    'free_text': freeText,
  };

  UserPreference copyWith({
    List<String>? likedGenres,
    List<String>? dislikedGenres,
    String? freeText,
  }) => UserPreference(
    likedGenres: likedGenres ?? this.likedGenres,
    dislikedGenres: dislikedGenres ?? this.dislikedGenres,
    freeText: freeText ?? this.freeText,
  );
}
