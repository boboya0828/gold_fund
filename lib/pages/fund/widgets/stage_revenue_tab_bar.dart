import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 阶段收益 Tab 数据项（阶段/月度/季度/半年/年度）
class StageRevenueTab {
  final String label;
  final String value;
  const StageRevenueTab(this.label, this.value);
}

/// 阶段收益 Tab 栏 — 1:1 复刻 stage-revenue.vue 的 .history-head-tabs
/// 每个 tab：flex:1，高 54rpx=27，圆角 999rpx，文字 22rpx=11；
/// 激活：浅 底 #FFF6E5 字 #F1B742 w700 / 深 底 rgba(224,86,101,0.14) 字 #E05665。
class StageRevenueTabBar extends StatelessWidget {
  final List<StageRevenueTab> tabs;
  final String activeValue;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const StageRevenueTabBar({
    super.key,
    required this.tabs,
    required this.activeValue,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(tab.value),
              child: Container(
                height: 27, // 54rpx
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: tab.value == activeValue
                      ? (isDark ? const Color(0x24E05665) : const Color(0xFFFFF6E5))
                      : Colors.transparent,
                ),
                child: Text(
                  tab.label,
                  style: AppTextStyles.cn(
                    11, // 22rpx
                    color: tab.value == activeValue
                        ? (isDark ? const Color(0xFFE05665) : const Color(0xFFF1B742))
                        : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF38415A)),
                    weight: tab.value == activeValue ? FontWeight.w700 : FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
