import 'dart:convert';

import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

enum ConnStatus { disconnected, connecting, connected, failed }

/// CineLink 桌面端二维码的解析结果。
///
/// 载荷格式（CineLink PhoneLinkPage 生成）：
/// `{"v":1,"app":"cinenest","name":"<PC名>","candidates":["http://ip:port",...]}`
class QrLinkPayload {
  QrLinkPayload({required this.pcName, required this.candidates});

  final String pcName;
  final List<Uri> candidates;

  static QrLinkPayload? tryParse(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['app'] != 'cinenest') return null;
      final candidates = (data['candidates'] as List? ?? const [])
          .whereType<String>()
          .map(Uri.tryParse)
          .whereType<Uri>()
          .where((u) => u.scheme == 'http' && u.host.isNotEmpty && u.hasPort)
          .toList();
      if (candidates.isEmpty) return null;
      return QrLinkPayload(
        pcName: (data['name'] as String?) ?? 'PC',
        candidates: candidates,
      );
    } catch (_) {
      return null;
    }
  }
}

class ConnectionService extends GetxService {
  static ConnectionService get to => Get.find<ConnectionService>();

  final Rx<ConnStatus> status = ConnStatus.disconnected.obs;
  final RxString message = ''.obs;

  String get baseUrl => Pref.baseUrl;

  @override
  void onInit() {
    super.onInit();
    Request.updateBaseUrl(baseUrl);
  }

  Future<void> updateAddress({required String host, required int port}) async {
    final url = 'http://$host:$port';
    await Pref.setPcHost(host);
    await Pref.setPcPort(port);
    await Pref.setBaseUrl(url);
    Request.updateBaseUrl(url);
    status.value = ConnStatus.disconnected;
    message.value = '';
  }

  /// 扫码连接：并发探测载荷里的候选地址，按候选顺序取第一个连通的。
  ///
  /// CineLink 会把当前选中的模式（局域网 / Tailscale / ZeroTier）排在 candidates 首位，
  /// 这里保持顺序优先级：即使后面的先返回，也等价取序号最小的成功者。
  /// 成功后写入 Hive 并热切 Dio baseUrl，返回连上的地址；全部失败返回 null。
  Future<String?> connectFromQr(QrLinkPayload payload) async {
    status.value = ConnStatus.connecting;
    message.value = '正在探测 ${payload.pcName} 的 ${payload.candidates.length} 个地址…';

    // 独立 Dio：短超时、不带全局重试拦截器，探测才够快
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 3000),
        receiveTimeout: const Duration(milliseconds: 3000),
      ),
    );
    try {
      final results = await Future.wait(
        payload.candidates.map((uri) async {
          try {
            final res = await probe.getUri(
              uri.replace(path: ApiConstants.health),
            );
            return res.statusCode == 200;
          } catch (_) {
            return false;
          }
        }),
      );
      final index = results.indexWhere((ok) => ok);
      if (index < 0) {
        status.value = ConnStatus.failed;
        message.value =
            '所有候选地址都连不上，请确认手机和 PC 在同一网络，或启用了同一个 Tailscale / ZeroTier 网络';
        return null;
      }
      final winner = payload.candidates[index];
      await updateAddress(host: winner.host, port: winner.port);
      status.value = ConnStatus.connected;
      message.value = '已通过扫码连接 ${payload.pcName}';
      logger.i('QR connect ok: $winner');
      return winner.toString();
    } finally {
      probe.close();
    }
  }

  Future<bool> testConnection() async {
    status.value = ConnStatus.connecting;
    message.value = 'Connecting to $baseUrl ...';
    try {
      final res = await Request().get(ApiConstants.health);
      if (res.statusCode == 200) {
        status.value = ConnStatus.connected;
        message.value = 'Connected.';
        logger.i('Backend connected: $baseUrl');
        return true;
      }
      status.value = ConnStatus.failed;
      message.value =
          (res.data is Map ? res.data['message'] as String? : null) ??
          'Connection failed: HTTP ${res.statusCode}.';
      return false;
    } catch (e) {
      status.value = ConnStatus.failed;
      message.value = 'Backend is not running or the address is wrong.';
      logger.w('Backend connection failed: $e');
      return false;
    }
  }
}
