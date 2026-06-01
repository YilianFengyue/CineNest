import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';

/// 全局日志实例（移植自 PiliPlus 的 `lib/services/logger.dart`，去掉 catcher2 文件落盘）。
///
/// debug 全量输出，release 仅警告以上。
final Logger logger = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
  level: kDebugMode ? Level.trace : Level.warning,
);
