class ForumPostSummary {
  const ForumPostSummary({
    required this.id,
    required this.title,
    required this.contentPreview,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
    required this.updatedAt,
    this.movieId,
    this.movieTitle,
    this.imageUrl,
    this.sticker,
  });

  final String id;
  final String title;
  final String contentPreview;
  final String authorName;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final String createdAt;
  final String updatedAt;
  final int? movieId;
  final String? movieTitle;
  final String? imageUrl;
  final String? sticker;

  factory ForumPostSummary.fromJson(Map<String, dynamic> json) =>
      ForumPostSummary(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        contentPreview: json['content_preview']?.toString() ?? '',
        authorName: json['author_name']?.toString() ?? '',
        likeCount: _asInt(json['like_count']),
        commentCount: _asInt(json['comment_count']),
        likedByMe: json['liked_by_me'] == true,
        createdAt: json['created_at']?.toString() ?? '',
        updatedAt: json['updated_at']?.toString() ?? '',
        movieId: json['movie_id'] is int
            ? json['movie_id'] as int
            : int.tryParse(json['movie_id']?.toString() ?? ''),
        movieTitle: json['movie_title']?.toString(),
        imageUrl: json['image_url']?.toString(),
        sticker: json['sticker']?.toString(),
      );
}

class ForumPostDetail {
  const ForumPostDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
    required this.updatedAt,
    this.movieId,
    this.movieTitle,
    this.imageUrl,
    this.sticker,
  });

  final String id;
  final String title;
  final String content;
  final String authorName;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final String createdAt;
  final String updatedAt;
  final int? movieId;
  final String? movieTitle;
  final String? imageUrl;
  final String? sticker;

  factory ForumPostDetail.fromJson(Map<String, dynamic> json) =>
      ForumPostDetail(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        authorName: json['author_name']?.toString() ?? '',
        likeCount: _asInt(json['like_count']),
        commentCount: _asInt(json['comment_count']),
        likedByMe: json['liked_by_me'] == true,
        createdAt: json['created_at']?.toString() ?? '',
        updatedAt: json['updated_at']?.toString() ?? '',
        movieId: json['movie_id'] is int
            ? json['movie_id'] as int
            : int.tryParse(json['movie_id']?.toString() ?? ''),
        movieTitle: json['movie_title']?.toString(),
        imageUrl: json['image_url']?.toString(),
        sticker: json['sticker']?.toString(),
      );
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String content;
  final String authorName;
  final String createdAt;

  factory ForumComment.fromJson(Map<String, dynamic> json) => ForumComment(
        id: json['id']?.toString() ?? '',
        postId: json['post_id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        authorName: json['author_name']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class ForumPostList {
  const ForumPostList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<ForumPostSummary> items;
  final int page;
  final int pageSize;
  final int total;

  factory ForumPostList.fromJson(Map<String, dynamic> json) => ForumPostList(
        items: (json['items'] is List ? json['items'] as List : const [])
            .whereType<Map>()
            .map((item) => ForumPostSummary.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        page: _asInt(json['page']),
        pageSize: _asInt(json['page_size']),
        total: _asInt(json['total']),
      );
}

class ForumPostDetailResponse {
  const ForumPostDetailResponse({required this.post, required this.comments});

  final ForumPostDetail post;
  final List<ForumComment> comments;

  factory ForumPostDetailResponse.fromJson(Map<String, dynamic> json) =>
      ForumPostDetailResponse(
        post: ForumPostDetail.fromJson(
          Map<String, dynamic>.from(json['post'] as Map),
        ),
        comments:
            (json['comments'] is List ? json['comments'] as List : const [])
                .whereType<Map>()
                .map((item) => ForumComment.fromJson(Map<String, dynamic>.from(item)))
                .toList(),
      );
}

int _asInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
