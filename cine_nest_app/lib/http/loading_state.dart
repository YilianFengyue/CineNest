import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 统一的异步数据状态封装（移植自 PiliPlus）。
///
/// 用法（sealed class + switch 模式匹配，编译期穷尽检查）：
/// ```dart
/// final res = await FeedApi.getFeed();
/// switch (res) {
///   case Success(:final response): // 成功，response 即数据
///   case Error(:final errMsg):     // 失败，errMsg 为错误信息
///   case Loading():                // 加载中
/// }
/// ```
sealed class LoadingState<T> {
  const LoadingState();

  factory LoadingState.loading() => const Loading._internal();

  bool get isSuccess => this is Success<T>;

  T get data => switch (this) {
    Success(:final response) => response,
    _ => throw this,
  };

  T? get dataOrNull => switch (this) {
    Success(:final response) => response,
    _ => null,
  };

  Future<void> toast() => SmartDialog.showToast(toString());
}

class Loading extends LoadingState<Never> {
  const Loading._internal();

  @override
  String toString() => 'loading';
}

@immutable
class Success<T> extends LoadingState<T> {
  final T response;
  const Success(this.response);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Success<T>) return response == other.response;
    return false;
  }

  @override
  int get hashCode => response.hashCode;
}

@immutable
class Error extends LoadingState<Never> {
  final int? code;
  final String? errMsg;
  const Error(this.errMsg, {this.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Error) return errMsg == other.errMsg && code == other.code;
    return false;
  }

  @override
  int get hashCode => Object.hash(errMsg, code);

  @override
  String toString() => errMsg ?? code?.toString() ?? '未知错误';
}
