import 'dart:convert';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/repositories/local_favorite_repository.dart';
import 'package:cine_nest/repositories/local_history_repository.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage.dart';

class AgentMemoryService {
  static const _lastSyncKey = 'agent_memory_last_sync_ms';
  static const _cooldownMs = 60 * 60 * 1000; // 1 小时

  final _historyRepo = LocalHistoryRepository();
  final _favoriteRepo = LocalFavoriteRepository();

  // ── 手动同步（无视冷却） ──

  Future<Map<String, dynamic>> syncLocalSignals() async {
    final result = await _doSync();
    _stampLastSync();
    return result;
  }

  // ── 自动同步（启动时调用，1h 内不重复） ──

  Future<void> autoSyncIfNeeded() async {
    final lastMs = GStorage.setting.get(_lastSyncKey, defaultValue: 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastMs < _cooldownMs) return;
    try {
      await _doSync();
      _stampLastSync();
      logger.i('[AgentMemory] 自动同步完成');
    } catch (e) {
      logger.w('[AgentMemory] 自动同步失败: $e');
    }
  }

  // ── 读取画像 ──

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await Request().get(ApiConstants.agentProfile);
    if ((response.statusCode ?? -1) < 200 ||
        (response.statusCode ?? -1) >= 300) {
      throw Exception((response.data as Map?)?['message'] ?? '读取画像失败');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── 重建画像 ──

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

  // ── 内部 ──

  Future<Map<String, dynamic>> _doSync() async {
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

  void _stampLastSync() {
    GStorage.setting.put(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }
}
