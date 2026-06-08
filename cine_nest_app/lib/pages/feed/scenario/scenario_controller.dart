import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/models/post.dart';
import 'package:cine_nest/http/feed_api.dart';

class ScenarioController extends GetxController {
  final TextEditingController inputController = TextEditingController();
  
  var postList = <Post>[].obs;
  var isLoading = false.obs;
  var debugInfo = RxnString();
  var currentScenario = "".obs;

  void onScenarioSelected(String scenario) {
    inputController.text = scenario;
    fetchRecommendations(scenario);
  }

  Future<void> fetchRecommendations(String scenario) async {
    if (scenario.isEmpty) return;
    
    try {
      debugPrint(">>> Fetching recommendations for scenario: $scenario");
      isLoading(true);
      currentScenario.value = scenario;
      debugInfo.value = null;
      
      final response = await FeedApi.getScenarioRecommendations(scenario: scenario);
      debugPrint(">>> Received response. Posts count: ${response.posts.length}");
      
      postList.assignAll(response.posts);
      debugInfo.value = response.debugInfo;
      
      if (response.posts.isEmpty) {
        debugPrint(">>> Warning: Backend returned empty posts list");
      }
      
    } catch (e, stack) {
      debugPrint(">>> Error fetching scenario recommendations: $e");
      debugPrint(stack.toString());
      Get.snackbar("推荐失败", e.toString());
    } finally {
      isLoading(false);
    }
  }

  @override
  void onClose() {
    inputController.dispose();
    super.onClose();
  }
}
