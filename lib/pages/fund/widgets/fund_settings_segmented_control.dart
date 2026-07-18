import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 分段控制器 — 1:1 复刻 settings.vue 的 .segmented-control + 滑动渐变指示器
///
/// 尺寸换算 rpx/2：高 70rpx=35，内边距 6rpx=3，圆角 20rpx=10；
/// 滑块 width calc(50% - 8rpx)，left calc(n*50% + 4rpx)，上下 6rpx=3，圆角 16rpx=8，
/// 渐变 90deg #FFF5DC → #F9D8D0，过渡 0.25s ease。
/// 注：源码 settings.vue 无深色模式样式，深色配色为适配补全。
class FundSettingsSegmentedControl extends StatelessWidget {
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const FundSettingsSegmentedControl({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF776F70);
    final activeTextColor = isDark ? const Color(0xFFF0F0F2) : const Color(0xFF4E3C34);
    return Container(
      height: 35, // 70rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE6202125) : const Color(0xE6FFFFFF), // rgba(*,0.9)
        borderRadius: BorderRadius.circular(10), // 20rpx
        border: Border.all(
          color: isDark ? const Color(0x0FFFFFFF) : const Color(0xF2F4E2DD), // 1rpx rgba(244,226,221,.95)
          width: 0.5,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F6E5A4E), // rgba(110,90,78,0.06)
                  offset: Offset(0, 5), // 10rpx
                  blurRadius: 15, // 30rpx
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final sliderW = w / 2 - 4; // calc(50% - 8rpx)
          final sliderLeft = activeIndex * (w / 2) + 2; // calc(n*50% + 4rpx)
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250), // transition all .25s ease
                curve: Curves.ease,
                left: sliderLeft,
                top: 3, // 6rpx
                bottom: 3,
                width: sliderW,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8), // 16rpx
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF3A3A3F), Color(0xFF2C2C31)]
                          : const [Color(0xFFFFF5DC), Color(0xFFF9D8D0)],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: Text(
                            tabs[i],
                            style: AppTextStyles.cn(
                              14, // 28rpx
                              color: i == activeIndex ? activeTextColor : textColor,
                              weight: i == activeIndex ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
