import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 历史净值表头 — 1:1 复刻 listed-net-value.vue 的 .net-table-head
/// 三列等宽：日期(左) / 净值(中) / 涨幅(右)；padding 6rpx 12rpx 18rpx，28rpx #8d8d8d
class ListedNavTableHeader extends StatelessWidget {
  final bool isDark;

  const ListedNavTableHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8D8D);
    final style = AppTextStyles.cn(14, color: color, height: 1.3); // 28rpx
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 9), // 6rpx 12rpx 18rpx
      child: Row(
        children: [
          Expanded(child: Text('日期', style: style)),
          Expanded(child: Text('净值', style: style, textAlign: TextAlign.center)),
          Expanded(child: Text('涨幅', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// 历史净值行 — 1:1 复刻 listed-net-value.vue 的 .net-row
/// min-height 84rpx=42，padding 0 12rpx，圆角 12rpx=6；
/// 涨行渐变 → #FFF5F6 / 跌行渐变 → #F2FFFC（深色 #322329 / #22302E）。
class ListedNavRow extends StatelessWidget {
  final bool isDark;
  final String date;
  final String unitValue;
  final String change;

  /// 源码 changeClass：(changeRatio ?? 0) >= 0 → is-rise
  final bool isRise;

  const ListedNavRow({
    super.key,
    required this.isDark,
    required this.date,
    required this.unitValue,
    required this.change,
    required this.isRise,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF242424);
    // 源码 .is-rise / .is-fall（浅色 #ff6b6b/#15b887，深色 #E05665/#10B4A1）
    final changeColor = isRise
        ? (isDark ? const Color(0xFFE05665) : const Color(0xFFFF6B6B))
        : (isDark ? const Color(0xFF10B4A1) : const Color(0xFF15B887));
    final gradientColors = isRise
        ? (isDark ? const [Color(0xFF282828), Color(0xFF322329)] : const [Color(0xFFFFFFFF), Color(0xFFFFF5F6)])
        : (isDark ? const [Color(0xFF282828), Color(0xFF22302E)] : const [Color(0xFFFFFFFF), Color(0xFFF2FFFC)]);
    const tabular = [FontFeature.tabularFigures()]; // font-variant-numeric: tabular-nums

    return Container(
      constraints: const BoxConstraints(minHeight: 42), // 84rpx
      padding: const EdgeInsets.symmetric(horizontal: 6), // 12rpx
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6), // 12rpx
        gradient: LinearGradient(colors: gradientColors),
        // 源码 box-shadow 0 1rpx 0 rgba(238,238,238,0.8)；深色无阴影
        border: isDark ? null : const Border(bottom: BorderSide(color: Color(0xCCEEEEEE), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(date, style: AppTextStyles.cn(13, color: textColor)), // 26rpx
          ),
          Expanded(
            child: Text(
              unitValue,
              textAlign: TextAlign.center,
              style: AppTextStyles.cn(13, color: textColor).copyWith(fontFeatures: tabular),
            ),
          ),
          Expanded(
            child: Text(
              change,
              textAlign: TextAlign.right,
              style: AppTextStyles.cn(13, color: changeColor).copyWith(fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}
