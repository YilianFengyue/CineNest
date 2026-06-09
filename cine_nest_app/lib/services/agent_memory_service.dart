import 'dart:convert';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/repositories/local_history_repository.dart';

class AgentMemoryService {
  final _historyRepo = LocalHistoryRepository();
  final _favoriteRepo = LocalFavoriteRepository();

  Future<Map<String, dynamic>> syncLocalSignals() async {
    final history = jsonDecode(_historyRepo.exportJson()) as List<dynamic>;
    final favorites = jsonDecode(_favoriteRepo.exportJson()) as List<dynamic>;
    final response = await Request().post(
      ApiConstants.agentMemorySync,
      data: {
        'user_id': 'default',
        'device_id': 'flutter',
        'exported_at': DateTime.now().millisecondsSinceEpoch,
        'history': history,
        'favorites': favorites,
      },
    );
    if ((response.statusCode ?? -1) < 200 ||
        (response.statusCode ?? -1) >= 300) {
      throw Exception((response.data as Map?)?['message'] ?? '同步画像失败');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await Request().get(ApiConstants.agentProfile);
    if ((response.statusCode ?? -1) < 200 ||
        (response.statusCode ?? -1) >= 300) {
      throw Exception((response.data as Map?)?['message'] ?? '读取画像失败');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> rebuildProfile() async {
    final response = await Request().post(
      ApiConstants.agentProfileRebuild,
      data: {'user_id': 'default', 'use_llm': false},
    );
    if ((response.statusCode ?? -1) < 200 ||
        (response.statusCode ?? -1) >= 300) {
      throw Exception((response.data as Map?)?['message'] ?? '重建画像失败');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
