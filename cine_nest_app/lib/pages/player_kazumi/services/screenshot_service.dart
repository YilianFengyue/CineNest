import 'package:saver_gallery/saver_gallery.dart';

import '../controller/player_controller.dart';

/// 截图并保存到系统相册。
class ScreenshotService {
  /// 抓取当前帧并保存。成功返回 true；失败返回 false 并把错误写入 [errorMessage]。
  static Future<({bool ok, String? errorMessage})> captureAndSave(
    KazumiPlayerController controller,
  ) async {
    final bytes = await controller.screenshot();
    if (bytes == null) {
      return (ok: false, errorMessage: '截图失败：未获取到画面');
    }
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: 'cinenest_$ts.png',
        skipIfExists: false,
      );
      if (result.isSuccess) {
        return (ok: true, errorMessage: null);
      }
      return (ok: false, errorMessage: result.errorMessage ?? '保存失败');
    } catch (e) {
      return (ok: false, errorMessage: '保存异常：$e');
    }
  }
}
