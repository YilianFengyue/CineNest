import 'package:cine_nest/http/api_constants.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/models/user_preference.dart';
import 'package:cine_nest/pages/feed/feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PreferenceController extends GetxController {
  final isLoading = true.obs;
  final isSaving = false.obs;

  final likedGenres = <String>[].obs;
  final dislikedGenres = <String>[].obs;
  final TextEditingController freeTextController = TextEditingController();

  final List<String> allGenres = const [
    '动作',
    '冒险',
    '动画',
    '喜剧',
    '犯罪',
    '纪录片',
    '剧情',
    '家庭',
    '奇幻',
    '历史',
    '恐怖',
    '音乐',
    '悬疑',
    '爱情',
    '科幻',
    '电视电影',
    '惊悚',
    '战争',
    '西部',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchPreferences();
  }

  @override
  void onClose() {
    freeTextController.dispose();
    super.onClose();
  }

  Future<void> fetchPreferences() async {
    try {
      isLoading(true);
      final response = await Request().get(ApiConstants.preferences);
      if (response.statusCode == 200 && response.data != null) {
        final pref = UserPreference.fromJson(response.data);
        likedGenres.assignAll(pref.likedGenres);
        dislikedGenres.assignAll(pref.dislikedGenres);
        freeTextController.text = pref.freeText ?? '';
      }
    } catch (e) {
      debugPrint('Fetch preferences failed: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> savePreferences() async {
    try {
      isSaving(true);
      final pref = UserPreference(
        likedGenres: likedGenres,
        dislikedGenres: dislikedGenres,
        freeText: freeTextController.text,
      );

      final response = await Request().post(
        ApiConstants.preferences,
        data: pref.toJson(),
      );

      if (response.statusCode == 200) {
        if (Get.isRegistered<FeedController>()) {
          await Get.find<FeedController>().loadData();
        }
        Get.snackbar('成功', '个性化偏好已更新', snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar(
          '错误',
          '保存失败: ${response.data}',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar('错误', '保存失败: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving(false);
    }
  }

  void toggleLike(String genre) {
    if (likedGenres.contains(genre)) {
      likedGenres.remove(genre);
    } else {
      likedGenres.add(genre);
      dislikedGenres.remove(genre);
    }
  }

  void toggleDislike(String genre) {
    if (dislikedGenres.contains(genre)) {
      dislikedGenres.remove(genre);
    } else {
      dislikedGenres.add(genre);
      likedGenres.remove(genre);
    }
  }
}
