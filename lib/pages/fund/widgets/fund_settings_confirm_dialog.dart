import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 通用确认弹窗 — 1:1 复刻 uni-app components/delectPopup.vue
/// 渐变卡片 + 顶部悬挂警告图标(tzico.png) + 取消/确认两枚圆角胶囊按钮
/// 尺寸换算 rpx/2：卡宽 600rpx=300，圆角 20rpx=10，图标 114rpx=57（悬挂 -50rpx=-25），
/// 标题 40rpx=20，正文 30rpx=15，按钮 248x84rpx=124x42 圆角 42rpx=21。
class FundSettingsConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool isDark;

  const FundSettingsConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '确认删除',
    this.cancelText = '取消',
    required this.isDark,
  });

  /// 确认返回 true，取消/点遮罩返回 false
  static Future<bool> show(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String content,
    String confirmText = '确认删除',
    String cancelText = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => FundSettingsConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDark: isDark,
      ),
    );
    return result ?? false;
  }

  static const _accent = AppColors.upColor; // #E05665

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final contentColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF666666);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300, // 600rpx
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 300,
                decoration: BoxDecoration(
                  // 源码 linear-gradient(0deg,#FFFFFF 0%,#FEF0F0 100%)（0deg 由下往上）
                  gradient: isDark
                      ? null
                      : const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFFFFFFFF), Color(0xFFFEF0F0)],
                        ),
                  color: isDark ? AppColors.darkSurface : null,
                  border: Border.all(
                    color: isDark ? AppColors.assetDividerDark : Colors.white,
                    width: 1, // 2rpx
                  ),
                  borderRadius: BorderRadius.circular(10), // 20rpx
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 42), // 图标下半 + 标题上距 20rpx
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cn(20, color: titleColor, weight: FontWeight.bold), // 40rpx
                    ),
                    const SizedBox(height: 18), // font2 margin-top 36rpx
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 21), // 42rpx
                      child: Text(
                        content,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cn(15, color: contentColor, height: 1.5), // 30rpx / 45rpx
                      ),
                    ),
                    const SizedBox(height: 23), // btn margin-top 46rpx
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 21),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _pill(text: cancelText, filled: false, onTap: () => Navigator.pop(context, false)),
                          _pill(text: confirmText, filled: true, onTap: () => Navigator.pop(context, true)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20), // margin-bottom 40rpx
                  ],
                ),
              ),
              // 顶部警告图标（悬挂 -50rpx）
              const Positioned(
                top: -25,
                left: 0,
                right: 0,
                child: Center(
                  child: Image(
                    image: AssetImage('assets/images/img/tzico.png'),
                    width: 57, // 114rpx
                    height: 57,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 胶囊按钮 248x84rpx=124x42，圆角 42rpx=21
  Widget _pill({required String text, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 124,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _accent : (isDark ? const Color(0xFF282828) : Colors.transparent),
          border: filled ? null : Border.all(color: _accent, width: 0.5), // 1rpx
          borderRadius: BorderRadius.circular(21),
        ),
        child: Text(
          text,
          style: AppTextStyles.cn(15, color: filled ? Colors.white : _accent), // 30rpx
        ),
      ),
    );
  }
}
