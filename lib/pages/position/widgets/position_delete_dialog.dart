import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 删除确认弹窗 — 1:1 复刻 uni-app components/delectPopup.vue
/// 渐变卡片 + 顶部警告图标(tzico.png) + 两枚圆角胶囊按钮
class PositionDeleteDialog extends StatelessWidget {
  final String assetName;
  final bool isDark;

  const PositionDeleteDialog({
    super.key,
    required this.assetName,
    required this.isDark,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String assetName,
    required bool isDark,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) =>
          PositionDeleteDialog(assetName: assetName, isDark: isDark),
    );
  }

  // 源码强调色 #E05665（.btnfont / .newDate 系）
  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final contentColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF666666);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300.sx, // 600rpx
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 卡片本体
              Container(
                width: 300.sx,
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
                    width: 1.sx, // 2rpx
                  ),
                  borderRadius: BorderRadius.circular(10.sx), // 20rpx
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 图标下半(约32) + 标题上距 20rpx(10)
                    SizedBox(height: 42.sx),
                    Text(
                      '确认删除',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cn(
                        20.sx, // 40rpx
                        color: titleColor,
                        weight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 18.sx), // font2 margin-top 36rpx
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 21.sx), // 42rpx
                      child: Text(
                        '确定要删除「$assetName」吗？',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cn(
                          15.sx, // 30rpx
                          color: contentColor,
                          height: 1.5, // line-height 45rpx / 30rpx
                        ),
                      ),
                    ),
                    SizedBox(height: 23.sx), // btn margin-top 46rpx
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 21.sx),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _pill(
                            context,
                            text: '取消',
                            filled: false,
                            onTap: () => Navigator.pop(context, false),
                          ),
                          _pill(
                            context,
                            text: '确认删除',
                            filled: true,
                            onTap: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.sx), // margin-bottom 40rpx
                  ],
                ),
              ),
              // 顶部警告图标（悬挂 -50rpx）
              Positioned(
                top: -25,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/img/tzico.png',
                    width: 57.sx, // 114rpx
                    height: 57.sx,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 胶囊按钮 248x84rpx=124x42, radius 42rpx=21
  Widget _pill(
    BuildContext context, {
    required String text,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 124.sx,
        height: 42.sx,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? _accent
              : (isDark ? const Color(0xFF282828) : Colors.transparent),
          border: filled ? null : Border.all(color: _accent, width: 0.5), // 1rpx
          borderRadius: BorderRadius.circular(21.sx),
        ),
        child: Text(
          text,
          style: AppTextStyles.cn(
            15.sx, // 30rpx
            color: filled ? Colors.white : _accent,
          ),
        ),
      ),
    );
  }
}
