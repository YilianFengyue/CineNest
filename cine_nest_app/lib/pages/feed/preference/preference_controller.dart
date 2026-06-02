import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/models/user_preference.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';

class PreferenceController extends GetxController {
  var isLoading = true.obs;
  var isSaving = false.obs;

  // 状态变量
  var likedGenres = <String>[].obs;
  var dislikedGenres = <String>[].obs;
  final TextEditingController freeTextController = TextEditingController();

  // 可选标签（与后端/TMDB对齐）
  final List<String> allGenres = [
    "动作", "冒险", "动画", "喜剧", "犯罪", "纪录", "剧情", "家庭", "奇幻",
    "历史", "恐怖", "音乐", "悬疑", "爱情", "科幻", "电视电影", "惊悚", "战争", "西部"
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

  // 从后端获取现有偏好
  Future<void> fetchPreferences() async {
    try {
      isLoading(true);
      final response = await Request().get(ApiConstants.preferences);
      if (response.data != null) {
        final pref = UserPreference.fromJson(response.data);
        likedGenres.assignAll(pref.likedGenres);
        dislikedGenres.assignAll(pref.dislikedGenres);
        freeTextController.text = pref.freeText ?? '';
      }
    } catch (e) {
      debugPrint("获取偏好失败: $e");
    } finally {
      isLoading(false);
    }
  }

  // 保存到后端
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
        Get.snackbar("成功", "个性化偏好已更新", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("错误", "保存失败: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving(false);
    }
  }

  void toggleLike(String genre) {
    if (likedGenres.contains(genre)) {
      likedGenres.remove(genre);
    } else {
      likedGenres.add(genre);
      dislikedGenres.remove(genre); // 互斥
    }
  }

  void toggleDislike(String genre) {
    if (dislikedGenres.contains(genre)) {
      dislikedGenres.remove(genre);
    } else {
      dislikedGenres.add(genre);
      likedGenres.remove(genre); // 互斥
    }
  }
}
