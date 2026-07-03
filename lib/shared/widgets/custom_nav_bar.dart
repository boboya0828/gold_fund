import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 自定义导航栏 — 1:1 复刻 uni-app CustomNavbar.vue
/// 高度 = 状态栏 + 44px, 左右 flex:1, 标题 flex:2
class CustomNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? rightWidget;
  final Widget? titleWidget;
  final Color? backgroundColor;
  final Color? titleColor;
  final String? backgroundImage;
  final double contentHeight;

  const CustomNavBar({
    super.key,
    this.title,
    this.showBack = true,
    this.onBack,
    this.rightWidget,
    this.titleWidget,
    this.backgroundColor,
    this.titleColor,
    this.backgroundImage,
    this.contentHeight = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bgColor = backgroundColor ?? (isDark ? AppColors.darkBg : AppColors.lightBg);
    final tColor = titleColor ?? (isDark ? Colors.white : Colors.black); // uni-app navigationFront

    return Container(
      color: bgColor,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: Stack(
        children: [
          if (backgroundImage != null)
            Positioned.fill(child: Image.asset(backgroundImage!, fit: BoxFit.cover)),
          SizedBox(
            height: contentHeight,
            child: Row(
              children: [
                // 左侧: flex 1, 返回按钮 (20px内边距对齐uni-app padding:0 40rpx)
                Expanded(
                  flex: 1,
                  child: showBack
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onBack ?? () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Image.asset(
                                'assets/images/img/leftico.png',
                                width: 8.5, height: 15.5, // 17×31rpx
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // 标题: Stack 居中 (不受左右 flex 影响)
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      titleWidget ??
                      Text(
                          title ?? '',
                          style: TextStyle(
                            fontSize: 16, // 32rpx
                            fontWeight: FontWeight.w400,
                            color: tColor,
                            fontFamily: 'siyuanheitiCNRegular',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                // 右侧: flex 1
                Expanded(
                  flex: 1,
                  child: rightWidget != null
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: rightWidget,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // 注意: uni-app 的 CustomNavbar 没有底部边框
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
      MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).padding.top + contentHeight);
}
