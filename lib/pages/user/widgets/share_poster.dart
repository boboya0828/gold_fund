import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 分享海报 — 1:1 复刻 uni-app pages/user/center/share.vue 的海报区
/// share.png 背景（高 908rpx）+ 右下角 rwmcode.png 二维码（100rpx，bottom 5%，right 30rpx）
///
/// uni-app 用隐藏 canvas（335×454）合成导出图片；
/// 这里用 RepaintBoundary 截图实现同等效果，无需额外依赖。
class SharePoster extends StatelessWidget {
  /// 用于截图的 RepaintBoundary key（由 SharePoster.capture 使用）
  final GlobalKey boundaryKey;

  const SharePoster({super.key, required this.boundaryKey});

  static const double posterHeight = 454; // 908rpx
  static const double qrSize = 50; // 100rpx

  /// 截取海报为 PNG 字节（对齐 uni-app canvasToTempFilePath）
  static Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 2}) async {
    final obj = key.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        height: posterHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景图 background-size: 100% 908rpx（拉伸填充）
            // TODO: assets/images/img/share.png 待加入 pubspec assets 声明
            Image.asset(
              'assets/images/img/share.png',
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFFF6F8FC)),
            ),
            // 二维码 bottom: 5%, right: 30rpx
            Positioned(
              right: 15, // 30rpx
              bottom: posterHeight * 0.05,
              child: Image.asset(
                'assets/images/img/rwmcode.png',
                width: qrSize,
                height: qrSize,
                errorBuilder: (context, error, stackTrace) => const SizedBox(width: qrSize, height: qrSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
