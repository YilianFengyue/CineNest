import 'package:cine_nest/utils/storage_pref.dart';

/// 把后端可能返回的相对资源 URL 解析成可加载的绝对 URL。
///
/// AI 生成的图片等存为后端 asset，URL 形如 `/api/assets/xxx`（相对）。
/// 这里按当前后端基址([Pref.baseUrl])补全；已是 http(s) 的绝对地址原样返回。
/// 基址随 F7 设置动态变化，因此换网络/IP 也无需改图片地址。
String mediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${Pref.baseUrl}$url';
  return url;
}
