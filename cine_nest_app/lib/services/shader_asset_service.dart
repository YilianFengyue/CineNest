import 'dart:io';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

const List<String> kAnime4KShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
];

const List<String> kAnime4KShadersLite = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
];

class ShaderAssetService {
  ShaderAssetService._();
  static final instance = ShaderAssetService._();

  Directory? _shadersDir;
  String get shadersPath => _shadersDir?.path ?? '';

  Future<void> ensureShadersCopied() async {
    if (_shadersDir != null) return;
    final appDir = await getApplicationSupportDirectory();
    _shadersDir = Directory(path.join(appDir.path, 'anime_shaders'));

    if (!await _shadersDir!.exists()) {
      await _shadersDir!.create(recursive: true);
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final shaderAssets = manifest.listAssets().where(
      (a) => a.startsWith('assets/shaders/') && a.endsWith('.glsl'),
    );

    for (final assetPath in shaderAssets) {
      final fileName = assetPath.split('/').last;
      final target = File(path.join(_shadersDir!.path, fileName));
      if (await target.exists()) continue;
      try {
        final data = await rootBundle.load(assetPath);
        await target.writeAsBytes(data.buffer.asUint8List());
        logger.i('[Shader] copied $fileName');
      } catch (e) {
        logger.w('[Shader] failed to copy $assetPath: $e');
      }
    }
  }
}

String buildShadersPath(String baseDir, List<String> shaders) {
  final paths = shaders.map((s) => path.join(baseDir, s)).toList();
  return Platform.isWindows ? paths.join(';') : paths.join(':');
}
