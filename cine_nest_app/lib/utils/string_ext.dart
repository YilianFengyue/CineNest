/// 字符串扩展（移植自 PiliPlus 的 `lib/utils/extension/string_ext.dart`）。
extension StringExt on String? {
  /// http:// 或协议相对地址统一转 https://。
  String get http2https =>
      this?.replaceFirst(RegExp(r'^(http:)?//'), 'https://') ?? '';

  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
