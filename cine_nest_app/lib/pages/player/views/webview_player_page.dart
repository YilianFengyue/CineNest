import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class WebViewPlayerPage extends StatefulWidget {
  const WebViewPlayerPage({super.key});

  @override
  State<WebViewPlayerPage> createState() => _WebViewPlayerPageState();
}

class _WebViewPlayerPageState extends State<WebViewPlayerPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String? _error;

  late final String _title = _readValue('title') ?? 'WebView Player';
  late final String _url = _sanitizeUrl(_readValue('url') ?? '');

  String? _readValue(String key) {
    final arguments = Get.arguments;
    if (arguments is Map) {
      final value = arguments[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final value = Get.parameters[key];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      return Uri.decodeComponent(value.trim());
    } catch (_) {
      return value.trim();
    }
  }

  String _sanitizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final safePercent = trimmed.replaceAllMapped(
      RegExp(r'%(?![0-9a-fA-F]{2})'),
      (_) => '%25',
    );
    final parsed = Uri.tryParse(safePercent);
    if (parsed == null || !parsed.hasScheme) {
      return safePercent;
    }
    return parsed.toString();
  }

  void _reload() {
    setState(() {
      _error = null;
      _progress = 0;
    });
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _url.isEmpty
          ? const Center(child: Text('No web URL provided.'))
          : Column(
              children: [
                if (_progress < 1)
                  LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(_url)),
                        initialSettings: InAppWebViewSettings(
                          allowsInlineMediaPlayback: true,
                          databaseEnabled: true,
                          domStorageEnabled: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          javaScriptEnabled: true,
                          mediaPlaybackRequiresUserGesture: false,
                          mixedContentMode:
                              MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          transparentBackground: false,
                          useShouldOverrideUrlLoading: true,
                          userAgent:
                              'Mozilla/5.0 (Linux; Android 12; Mobile) '
                              'AppleWebKit/537.36 (KHTML, like Gecko) '
                              'Chrome/125.0 Mobile Safari/537.36',
                        ),
                        onWebViewCreated: (controller) {
                          _controller = controller;
                        },
                        onProgressChanged: (controller, progress) {
                          if (mounted) {
                            setState(() => _progress = progress / 100);
                          }
                        },
                        onLoadStop: (controller, url) {
                          if (mounted) {
                            setState(() {
                              _progress = 1;
                              _error = null;
                            });
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          if (request.isForMainFrame == false) {
                            return;
                          }
                          if (mounted) {
                            setState(() {
                              _progress = 1;
                              _error = error.description;
                            });
                          }
                        },
                      ),
                      if (_progress == 0 && _error == null)
                        const Center(child: CircularProgressIndicator()),
                      if (_error != null)
                        _WebErrorPanel(
                          error: _error!,
                          url: _url,
                          onRetry: _reload,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _url,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}

class _WebErrorPanel extends StatelessWidget {
  const _WebErrorPanel({
    required this.error,
    required this.url,
    required this.onRetry,
  });

  final String error;
  final String url;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_off, size: 48),
              const SizedBox(height: 12),
              Text(
                'WebView load failed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              SelectableText(url, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
