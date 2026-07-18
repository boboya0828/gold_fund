import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 删除/清空二次确认弹窗 — 1:1 复刻 uni-app components/delectPopup.vue
/// 渐变卡片 + 顶部悬挂警告图标(tzico.png) + 取消/确认两枚圆角胶囊按钮
class LedgerConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool isDark;

  const LedgerConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.isDark,
    this.confirmText = '确认删除',
    this.cancelText = '取消',
  });

  /// 弹出确认框, 返回 true=确认, false/null=取消
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    required bool isDark,
    String confirmText = '确认删除',
    String cancelText = '取消',
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => LedgerConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDark: isDark,
      ),
    );
  }

  // 源码强调色 #E05665
  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final contentColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666);

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
                  color: isDark ? const Color(0xFF202125) : null,
                  border: Border.all(
                    color: isDark ? const Color(0xFF2B2D33) : Colors.white,
                    width: 1, // 2rpx
                  ),
                  borderRadius: BorderRadius.circular(10), // 20rpx
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 42), // 图标下半 + margin-top 20rpx
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cn(20, color: titleColor, weight: FontWeight.bold), // 40rpx bold
                    ),
                    const SizedBox(height: 18), // font2 margin-top 36rpx
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 21), // 42rpx
                      child: Text(
                        content,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cn(15, color: contentColor, height: 1.5), // 30rpx, line-height 45rpx
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
              Positioned(
                top: -25,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset('assets/images/img/tzico.png', width: 57, height: 57), // 114rpx
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 胶囊按钮 248x84rpx=124x42, radius 42rpx=21
  Widget _pill({required String text, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
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
        child: Text(text, style: AppTextStyles.cn(15, color: filled ? Colors.white : _accent)), // 30rpx
      ),
    );
  }
}
