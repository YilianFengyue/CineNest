import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:get/get.dart';

enum ConnStatus { disconnected, connecting, connected, failed }

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
