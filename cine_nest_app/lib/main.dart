import 'dart:io';

import 'package:cine_nest/app.dart';
import 'package:cine_nest/http/init.dart';
import 'package:cine_nest/services/connection_service.dart';
import 'package:cine_nest/services/logger.dart';
import 'package:cine_nest/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

/// 应用入口。
///
/// 初始化时序仿照 PiliPlus 母版（裁剪掉桌面 window_manager / catcher2 / B站账号链路）：
///   1. MediaKit 初始化（成员 A 的播放器底座）
///   2. GStorage（Hive）初始化 —— 必须最先，后续 Pref 读取依赖它
///   3. 全局 Service 注册（ConnectionService）
///   4. Request() 初始化 Dio
///   5. 系统 UI 样式
///   6. runApp
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  try {
    await GStorage.init();
  } catch (e) {
    logger.e('GStorage 初始化失败: $e');
    exit(0);
  }

  // 先初始化 Dio 单例：必须早于 ConnectionService，
  // 因为 ConnectionService.onInit 会读取 Request.dio 同步基址。
  Request();
  // 再注册全局单例 Service（onInit 把持久化基址同步给 Dio）
  Get.put(ConnectionService(), permanent: true);

  // 移动端沉浸式系统栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const MyApp());
}
