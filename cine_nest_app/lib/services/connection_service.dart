import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:get/get.dart';

/// PC 连接状态枚举（F7）。
enum ConnStatus { disconnected, connecting, connected, failed }

/// 全局连接服务（F7 的基建，三人共用）。
///
/// 职责：
///   · 管理「PC 后端基址」（host:port → baseUrl），并同步到 [Request] 的 Dio。
///   · 提供连接测试（ping `/api/health`）与响应式连接状态 [status]。
///
/// 成员 A 在设置页负责连接配置 UI，调用 [updateAddress] / [testConnection]；
/// 其余成员只需读取 [status] 决定是否拉取数据。
///
/// 通过 GetX 注册为全局单例：`Get.put(ConnectionService())`（见 main.dart）。
class ConnectionService extends GetxService {
  static ConnectionService get to => Get.find<ConnectionService>();

  final Rx<ConnStatus> status = ConnStatus.disconnected.obs;
  final RxString message = ''.obs;

  /// 当前后端基址（http://host:port）。
  String get baseUrl => Pref.baseUrl;

  @override
  void onInit() {
    super.onInit();
    // 启动时把持久化的基址同步给 Dio。
    Request.updateBaseUrl(baseUrl);
  }

  /// 更新 PC 地址并持久化，同步到 Dio。
  Future<void> updateAddress({required String host, required int port}) async {
    final url = 'http://$host:$port';
    await Pref.setPcHost(host);
    await Pref.setPcPort(port);
    await Pref.setBaseUrl(url);
    Request.updateBaseUrl(url);
    status.value = ConnStatus.disconnected;
    message.value = '';
  }

  /// 测试连接：GET /api/health。成功置为 connected。
  Future<bool> testConnection() async {
    status.value = ConnStatus.connecting;
    message.value = '正在连接 $baseUrl …';
    try {
      final res = await Request().get(ApiConstants.health);
      if (res.statusCode == 200) {
        status.value = ConnStatus.connected;
        message.value = '已连接';
        logger.i('后端连接成功: $baseUrl');
        return true;
      }
      status.value = ConnStatus.failed;
      message.value = (res.data is Map ? res.data['message'] : null) ??
          '连接失败（HTTP ${res.statusCode}）';
      return false;
    } catch (e) {
      status.value = ConnStatus.failed;
      message.value = 'PC 端服务未启动或地址错误';
      logger.w('后端连接失败: $e');
      return false;
    }
  }
}
