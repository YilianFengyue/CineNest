import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cine_nest/models/movie.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/http/api_constants.dart';

class DiscoveryController extends GetxController {
  var isLoading = true.obs;
  var movieList = <Movie>[].obs;
  int _page = 1;

  String get baseUrl => Request.dio.options.baseUrl;

  @override
  void onInit() {
    super.onInit();
    // 延迟到首帧渲染后再加载数据，避免阻塞启动线程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  Future<void> loadData() async {
    try {
      isLoading(true);
      _page = 1;
      debugPrint(">>> [Discovery] 开始加载热门数据...");
      final response = await Request().get(ApiConstants.discovery, queryParameters: {'page': _page});
      
      if (response.data is List) {
        List data = response.data;
        final list = data.map((json) {
          try {
            return Movie.fromJson(json);
          } catch (e) {
            debugPrint(">>> [Discovery] 解析单部电影失败: $e");
            return null;
          }
        }).whereType<Movie>().toList();
        
        movieList.assignAll(list);
        debugPrint(">>> [Discovery] 成功加载 ${list.length} 部电影");
      } else {
        debugPrint(">>> [Discovery] 返回数据格式错误: ${response.data}");
      }
    } catch (e) {
      debugPrint(">>> [Discovery] 加载数据异常: $e");
      Get.snackbar("提示", "无法连接到后端，请检查网络");
    } finally {
      isLoading(false);
    }
  }

  Future<void> loadMore() async {
    try {
      _page++;
      final response = await Request().get(ApiConstants.discovery, queryParameters: {'page': _page});
      if (response.data is List) {
        List data = response.data;
        final list = data.map((json) {
          try {
            return Movie.fromJson(json);
          } catch (e) {
            return null;
          }
        }).whereType<Movie>().toList();
        movieList.addAll(list);
      }
    } catch (e) {
      _page--;
    }
  }
}
