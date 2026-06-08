import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:brotli/brotli.dart';
import 'package:cine_nest/http/retry_interceptor.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Dio HTTP 客户端封装（移植自 PiliPlus 的 `lib/http/init.dart`）。
///
/// 保留的通用基建：
///   · 单例 + HTTP/1.1 适配器（FastAPI/uvicorn 默认通道）
///   · gzip / brotli 响应解压（Http2Adapter 不自动解压）
///   · [RetryInterceptor] 通用重试
///   · debug 下的 LogInterceptor、后台线程 JSON 解析
///   · DioException → 友好错误信息 的统一封装
///
/// 已剔除的 B站强相关逻辑：
///   · AccountManager 拦截器、WBI 签名、Cookie/account_key 注入
///   · setCookie / buvidActive / setCoin 等账号链路
class Request {
  static final _gzipDecoder = GZipDecoder();
  static final _brotliDecoder = BrotliDecoder();

  static final Request _instance = Request._internal();
  // FastAPI/uvicorn 默认是 HTTP/1.1；移动端强行 HTTP/2 会出现
  // "Connection is being forcefully terminated"。保留 Pref 字段给以后设置页扩展，
  // 当前主通道固定走 HTTP/1.1。
  static const bool _enableHttp2 = false;
  static late final Dio dio;

  factory Request() => _instance;

  Request._internal() {
    final BaseOptions options = BaseOptions(
      baseUrl: Pref.baseUrl,
      connectTimeout: const Duration(milliseconds: 15000),
      receiveTimeout: const Duration(milliseconds: 30000), // AI 生成较慢，延长至 2 分钟
      headers: {
        'user-agent': 'CineNest/1.0 (Flutter; dart:io)',
        if (!_enableHttp2) 'connection': 'keep-alive',
        'accept-encoding': 'br,gzip',
      },
      responseDecoder: _responseDecoder,
      persistentConnection: true,
    );

    final h11 = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..idleTimeout = const Duration(seconds: 15)
        ..autoUncompress = false, // 统一交给 _responseDecoder 解压
    );

    dio = Dio(options)
      ..httpClientAdapter = _enableHttp2
          ? Http2Adapter(
              ConnectionManager(idleTimeout: const Duration(seconds: 15)),
              fallbackAdapter: h11,
            )
          : h11;

    // 重试拦截器需先于其他拦截器
    if (Pref.retryCount != 0) {
      dio.interceptors.add(
        RetryInterceptor(dio, Pref.retryCount, Pref.retryDelay),
      );
    }

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }

    dio
      ..transformer = BackgroundTransformer()
      ..options.validateStatus = (int? status) =>
          status != null && status >= 200 && status < 300;
  }

  /// 运行期切换后端基址（设置页填写 PC 的 IP:Port 后调用）。见 ConnectionService。
  static void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }

  Future<Response> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get<T>(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _errorResponse(e);
    }
  }

  Future<Response> post<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.post<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _errorResponse(e);
    }
  }

  Future<Response> downloadFile(
    String urlPath,
    String savePath, {
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.download(
        urlPath,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      return _errorResponse(e);
    }
  }

  static Response _errorResponse(DioException e) => Response(
    data: {'message': dioError(e)},
    statusCode: e.response?.statusCode ?? -1,
    requestOptions: e.requestOptions,
  );

  /// 将 DioException 翻译成中文友好提示（替代 AccountManager.dioError）。
  static String dioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查 PC 端服务是否启动';
      case DioExceptionType.sendTimeout:
        return '请求发送超时';
      case DioExceptionType.receiveTimeout:
        return '响应接收超时';
      case DioExceptionType.badCertificate:
        return '证书校验失败';
      case DioExceptionType.badResponse:
        return '服务器返回错误：${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '无法连接到 PC 端，请检查 IP:Port 与局域网';
      case DioExceptionType.unknown:
        return '网络异常：${e.message ?? e.error}';
    }
  }

  static List<int> _responseBytesDecoder(
    List<int> responseBytes,
    Map<String, List<String>> headers,
  ) {
    switch (headers['content-encoding']?.firstOrNull) {
      case 'gzip':
        return _gzipDecoder.decodeBytes(responseBytes);
      case 'br':
        return _brotliDecoder.convert(responseBytes);
      default:
        return responseBytes;
    }
  }

  static String _responseDecoder(
    List<int> responseBytes,
    RequestOptions options,
    ResponseBody responseBody,
  ) => utf8.decode(
    _responseBytesDecoder(responseBytes, responseBody.headers),
    allowMalformed: true,
  );
}
