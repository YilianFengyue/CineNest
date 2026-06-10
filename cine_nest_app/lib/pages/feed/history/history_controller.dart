import 'package:cine_nest/http/init.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class HistoryController extends GetxController {
  final isLoading = true.obs;
  final historyList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      isLoading(true);
      final response = await Request().get('/api/history');
      if (response.statusCode == 200 && response.data is List) {
        historyList.assignAll(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Fetch history failed: $e');
    } finally {
      isLoading(false);
    }
  }
}
