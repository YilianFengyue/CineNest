import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/modules/media_aggregator/models/media_models.dart';

class DebateRecommendationService {
  Future<Map<String, dynamic>> generate({
    required AggregatorMediaDetail detail,
    String? episodeName,
  }) async {
    final title =
        (detail.tmdb?.title?.isNotEmpty == true
                ? detail.tmdb!.title
                : detail.title)
            .toString()
            .trim();
    final tags = <String>{
      if (detail.category?.isNotEmpty == true) detail.category!,
      if (detail.typeName?.isNotEmpty == true) detail.typeName!,
      ...?detail.tmdb?.genres,
    }.toList();

    final overview = detail.tmdb?.overview ?? detail.desc ?? '';
    final rating = detail.tmdb?.rating?.toStringAsFixed(1);

    final response = await Request().post(
      ApiConstants.agentDebateRecommend,
      data: {
        'user_id': 'default',
        'movie': title.isNotEmpty ? title : detail.title,
        'year': detail.year ?? '',
        'overview': overview,
        'source_name': detail.sourceName,
        'episode_name': episodeName ?? '',
        'playable': detail.episodes.any((item) => item.isPlayableDirectUrl),
        'rating': rating ?? '',
        'tags': tags,
        'model': 'default',
      },
    );
    if ((response.statusCode ?? -1) < 200 ||
        (response.statusCode ?? -1) >= 300) {
      throw Exception((response.data as Map?)?['message'] ?? '生成推荐委员会失败');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
