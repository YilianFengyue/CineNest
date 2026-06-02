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

class Request {
  static final _gzipDecoder = GZipDecoder();
  static final _brotliDecoder = BrotliDecoder();

  // 1. 保持单例私有构造
  static final Request _instance = Request._internal();
  static final bool _enableHttp2 = Pref.enableHttp2;

  // ✨ 修改点：去掉 static 和 late，让 dio 成为单例的普通实例属性
  final Dio dio;

  factory Request() => _instance;

  Request._internal() : dio = Dio() { // ✨ 在初始化列表中直接完成 dio 的内存分配，断绝 late 未初始化漏洞
    final BaseOptions options = BaseOptions(
      baseUrl: Pref.baseUrl,
      connectTimeout: const Duration(milliseconds: 15000),
      receiveTimeout: const Duration(milliseconds: 60000), // AI 生成较慢，增加到 60s
      headers: {
        'user-agent': 'CineNest/1.0 (Flutter; dart:io)',
        if (!_enableHttp2) 'connection': 'keep-alive',
        'accept-encoding': 'br,gzip',
      },
      responseDecoder: _responseDecoder,
      persistentConnection: true,
    );

    // 将配置同步给 dio
    dio.options = options;

    final h11 = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..idleTimeout = const Duration(seconds: 15)
        ..autoUncompress = false,
    );

    dio.httpClientAdapter = _enableHttp2
        ? Http2Adapter(
            ConnectionManager(idleTimeout: const Duration(seconds: 15)),
            fallbackAdapter: h11,
          )
        : h11;

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
      ..options.validateStatus =
          (int? status) => status != null && status >= 200 && status < 300;
  }

  /// ✨ 修改点：由于 dio 变成了实例属性，运行期切换基址应通过单例实例修改
  static void updateBaseUrl(String baseUrl) {
    _instance.dio.options.baseUrl = baseUrl;
  }

  Future<Response> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get<T>( // ✨ 去掉 static 后这里直接用实例的 dio
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
      return await dio.post<T>( // ✨ 同上
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