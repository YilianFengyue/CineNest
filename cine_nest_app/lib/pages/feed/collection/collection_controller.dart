import 'package:cine_nest/http/init.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class CollectionController extends GetxController {
  final isLoading = true.obs;
  final collectionList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchCollections();
  }

  Future<void> fetchCollections() async {
    try {
      isLoading(true);
      final response = await Request().get('/api/collections');
      if (response.statusCode == 200 && response.data is List) {
        collectionList.assignAll(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Fetch collections failed: $e');
    } finally {
      isLoading(false);
    }
  }
}
