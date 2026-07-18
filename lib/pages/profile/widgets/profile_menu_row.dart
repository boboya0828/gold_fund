import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'dark_mode_icon.dart';

/// 我的页功能菜单行 - 1:1 复刻 uni-app pages/user/index.vue 的 .list2
///
/// 行高 116rpx=58；左右间距 40rpx=20；图标 33rpx=16.5（深色自动加载 -b 变体，
/// 对齐 getUserIcon）；文字 30rpx=15；右箭头 13x24rpx=6.5x12（margin-top 4rpx=2）；
/// 底部分隔线 1rpx=0.5（#F6F6F6 / 深色 #2B2D33）。
class ProfileMenuRow extends StatelessWidget {
  /// 图标基名（如 uico4），深色模式自动切换 -b 变体
  final String iconBase;
  final String label;
  final VoidCallback onTap;

  /// 是否显示底部分隔线。vue 中 .list2:last-child 无边框，故每个菜单盒的末行传 false。
  final bool showDivider;

  const ProfileMenuRow({
    super.key,
    required this.iconBase,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .list2 border-bottom: 1rpx solid #F6F6F6；.theme-dark .list2 → #2B2D33
    final dividerColor = isDark ? AppColors.assetDividerDark : const Color(0xFFF6F6F6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: showDivider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)))
            : null,
        child: Row(children: [
          Image.asset('assets/images/img/$iconBase${isDark ? '-b' : ''}.png', width: 16.5, height: 16.5),
          const SizedBox(width: 8), // .font8 margin-left 16rpx
          // 浅色模式 .font8 未指定颜色，继承 webview 默认黑色；.theme-dark .font8 → #D7DAE0
          Expanded(
            child: Text(label, style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : Colors.black)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2), // .navto1 image margin-top 4rpx
            child: DarkModeIconFilter(
              isDark: isDark,
              child: Image.asset('assets/images/img/right-ico.png', width: 6.5, height: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
