import 'package:dio/dio.dart';

class SourcePreflightResult {
  const SourcePreflightResult({
    required this.ok,
    required this.elapsedMs,
    this.error,
  });

  final bool ok;
  final int elapsedMs;
  final String? error;
}

class SourcePreflightService {
  SourcePreflightService({Dio? dio, this.timeout = const Duration(seconds: 5)})
    : _dio = dio ?? Dio();

  final Dio _dio;
  final Duration timeout;

  Future<SourcePreflightResult> probe(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final sw = Stopwatch()..start();
    try {
      final mergedHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Range': 'bytes=0-1024',
        ...headers,
      };
      await _dio
          .get<Object?>(
            url,
            options: Options(
              headers: mergedHeaders,
              responseType: ResponseType.bytes,
              sendTimeout: timeout,
              receiveTimeout: timeout,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 500,
            ),
          )
          .timeout(timeout);
      return SourcePreflightResult(ok: true, elapsedMs: sw.elapsedMilliseconds);
    } catch (e) {
      return SourcePreflightResult(
        ok: false,
        elapsedMs: sw.elapsedMilliseconds,
        error: _friendly(e),
      );
    }
  }

  String _friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('TimeoutException') || raw.contains('timeout')) {
      return '探测超时';
    }
    if (raw.contains('403') || raw.contains('401')) {
      return '源鉴权失败';
    }
    if (raw.contains('SocketException')) {
      return '网络连接失败';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }
}
