import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/share_poster.dart';

/// 分享 App 页 — 1:1 复刻 uni-app pages/user/center/share.vue
/// 海报（share.png + 二维码）+ 保存图片 / 微信分享 两个圆形按钮
///
/// 平台专有能力说明：
/// - uni-app 的「保存图片到相册」无对应可用依赖，改为 share_plus 调起系统分享
///   面板（用户可在面板中选择“存储图像”等保存方式）。
/// - uni-app 的「微信好友直分享」需要微信 SDK，同样降级为系统分享面板。
/// - umeng 埋点未迁移。
class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _busy = false;
  bool _loadingShown = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// uni-app uni.showLoading({ mask: true })
  void _showLoading(String title) {
    _loadingShown = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : const Color(0xFF333333),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => _loadingShown = false);
  }

  void _hideLoading() {
    if (_loadingShown && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// 生成海报图并调起系统分享（对齐 uni-app onSaveImage / onShareWechat）
  Future<void> _generateAndShare({required bool isSaveAction}) async {
    if (_busy) return;
    setState(() => _busy = true);
    _showLoading(isSaveAction ? '正在生成...' : '准备分享...');
    try {
      final bytes = await SharePoster.capture(_posterKey, pixelRatio: 2);
      if (bytes == null) throw Exception('生成图片失败');
      _hideLoading();
      final result = await Share.shareXFiles(
        [XFile.fromData(bytes, name: '养基助手.png', mimeType: 'image/png')],
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _toast(isSaveAction ? '保存成功' : '分享成功');
      }
    } catch (_) {
      _hideLoading();
      _toast(isSaveAction ? '保存失败' : '分享失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: CustomNavBar(
        title: '分享APP',
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 10), // 0 30rpx, margin-top 20rpx
          child: Column(
            children: [
              // 海报（margin: 120rpx 40rpx）
              Container(
                margin: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 60),
                child: SharePoster(boundaryKey: _posterKey),
              ),
              // 底部两个圆形按钮（间隔 126rpx）
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 保存图片（uni-app shareico2.png）
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _generateAndShare(isSaveAction: true),
                    child: Image.asset(
                      'assets/images/img/shareico2.png',
                      width: 50, // 100rpx
                      height: 50,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.save_alt, size: 50),
                    ),
                  ),
                  const SizedBox(width: 63), // 126rpx
                  // 微信分享（uni-app shareico1.png）
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _generateAndShare(isSaveAction: false),
                    child: Image.asset(
                      'assets/images/img/shareico1.png',
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.share, size: 50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
