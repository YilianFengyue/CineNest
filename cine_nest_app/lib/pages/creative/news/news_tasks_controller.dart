import 'dart:async';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

/// 一条资讯生成任务（异步队列）。
///
/// 字段对齐与 codex 约定的后端契约：
/// `{ task_id, query, status: queued|running|done|failed, stage?, news_id?, error? }`
class NewsTask {
  final String id;
  final String query;
  final String status;
  final String stage;
  final String? newsId;
  final String? error;

  const NewsTask({
    required this.id,
    required this.query,
    required this.status,
    this.stage = '',
    this.newsId,
    this.error,
  });

  factory NewsTask.fromJson(Map<String, dynamic> j) => NewsTask(
    id: (j['task_id'] ?? j['id'] ?? '').toString(),
    query: (j['query'] ?? '').toString(),
    status: (j['status'] ?? 'queued').toString(),
    stage: (j['stage'] ?? '').toString(),
    newsId: j['news_id'] as String?,
    error: j['error'] as String?,
  );

  bool get isActive => status == 'queued' || status == 'running';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  /// 0~1 进度（用于进度条）。后端没有数值进度，这里按 status/stage 估一个友好值。
  double get progress {
    switch (status) {
      case 'done':
      case 'failed':
        return 1.0;
      case 'running':
        if (stage.contains('图')) return 0.82; // 生图阶段
        if (stage.contains('资料') || stage.contains('搜')) return 0.5; // 搜资料
        return 0.65;
      default:
        return 0.15; // queued
    }
  }

  /// 友好状态文案。
  String get statusLabel {
    switch (status) {
      case 'done':
        return '已完成';
      case 'failed':
        return '失败';
      case 'running':
        return stage.isEmpty ? '生成中' : stage;
      default:
        return stage.isEmpty ? '排队中' : stage;
    }
  }
}

/// 资讯生成任务队列控制器（F12）。
///
/// 职责：轮询 `GET /api/news/tasks` 拿任务状态；提交 `POST /api/news/generate` 起新任务。
/// 后端（codex 实现中）把生成改成后台异步：提交立即返回，生图在后台跑、完成落库。
/// 后端未就绪时回退一组 mock 任务，UI 先可调。
class NewsTasksController extends GetxController {
  /// 全局单例（懒加载常驻）：chat 与资讯页共用同一个轮询源。
  static NewsTasksController get to => Get.isRegistered<NewsTasksController>()
      ? Get.find<NewsTasksController>()
      : Get.put(NewsTasksController(), permanent: true);

  final RxList<NewsTask> tasks = <NewsTask>[].obs;
  final RxBool usingMock = false.obs;
  final RxBool submitting = false.obs;

  /// 最近一条"刚完成"的任务（用于资讯页完成通知）；null 表示无待提示。
  final RxnString completedQuery = RxnString();
  String completedNewsId = '';

  final Set<String> _seenDone = {};
  bool _primed = false; // 首次拉取只记录已完成，不弹历史通知

  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    fetch();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => fetch());
  }

  /// 当前进行中的任务（队列条只显示这些）。
  List<NewsTask> get active => tasks.where((t) => t.isActive).toList();

  /// 清掉完成通知（用户点过"查看"后）。
  void clearCompleted() => completedQuery.value = null;

  /// 检测新完成的任务 → 设置完成通知。
  void _detectCompletion() {
    final doneNow = tasks.where((t) => t.isDone);
    if (!_primed) {
      _seenDone.addAll(doneNow.map((t) => t.id));
      _primed = true;
      return;
    }
    for (final t in doneNow) {
      if (_seenDone.add(t.id)) {
        completedQuery.value = t.query;
        completedNewsId = t.newsId ?? '';
      }
    }
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  Future<void> fetch() async {
    try {
      final res = await Request().get(ApiConstants.newsTasks);
      final data = res.data;
      final raw = data is Map ? data['tasks'] : data;
      if (res.statusCode == 200 && raw is List) {
        tasks.value = raw
            .whereType<Map>()
            .map((e) => NewsTask.fromJson(e.cast<String, dynamic>()))
            .toList();
        usingMock.value = false;
        _detectCompletion();
        return;
      }
      _fallbackToMock();
    } catch (e) {
      logger.w('任务队列拉取失败，回退 mock: $e');
      _fallbackToMock();
    }
  }

  void _fallbackToMock() {
    if (tasks.isEmpty || usingMock.value) {
      tasks.value = _mockTasks();
      usingMock.value = true;
    }
  }

  /// 提交一条新生成任务。乐观插入排队条，再交后端，最后刷新。
  Future<bool> submit(String query) async {
    final q = query.trim();
    if (q.isEmpty || submitting.value) return false;
    submitting.value = true;
    tasks.insert(
      0,
      NewsTask(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        query: q,
        status: 'queued',
        stage: '已提交',
      ),
    );
    try {
      await Request().post(
        ApiConstants.newsGenerate,
        data: {'query': q},
        // 后端转异步前，生成仍可能较慢，给足超时不被默认 10s 掐断。
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
    } catch (e) {
      logger.w('提交生成任务失败: $e');
    }
    submitting.value = false;
    await fetch();
    return true;
  }

  List<NewsTask> _mockTasks() => const [
    NewsTask(
      id: 'm1',
      query: '沙丘 3',
      status: 'done',
      stage: '已完成',
      newsId: 'mock-news-1',
    ),
    NewsTask(id: 'm2', query: '奥本海默 续作', status: 'running', stage: 'AI 生图中'),
    NewsTask(id: 'm3', query: '某冷门片', status: 'queued', stage: '排队中'),
    NewsTask(
      id: 'm4',
      query: '不存在的电影',
      status: 'failed',
      error: '未找到相关影视资料',
    ),
  ];
}
