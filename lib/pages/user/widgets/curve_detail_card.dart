import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import 'curve_calendar_card.dart' show CurveSectionTitle;

/// 盈亏明细条目
class CurveDetailItem {
  final String name;
  final String value; // '+12.34'
  final int percentage; // 0-100

  const CurveDetailItem({required this.name, required this.value, required this.percentage});
}

/// 盈亏明细 TOP5 卡 — 1:1 复刻 uni-app curve.vue `.curve-detai-llist`
/// 标题(日期联动) + 盈利/亏损 Tab + 奖牌排行 + 进度条
class CurveDetailCard extends StatelessWidget {
  final bool isDark;
  final String title; // '当日盈亏明细' / '5月12号盈亏明细'
  final String activeTab; // '盈利TOP5' / '亏损TOP5'
  final List<CurveDetailItem> items;
  final bool amountHidden;
  final ValueChanged<String> onTabChange;
  final VoidCallback onShowAll;

  static const tabs = ['盈利TOP5', '亏损TOP5'];
  static const medalColors = [Color(0xFFFFBE37), Color(0xFFC7D1DD), Color(0xFFFF944D)];

  const CurveDetailCard({
    super.key,
    required this.isDark,
    required this.title,
    required this.activeTab,
    required this.items,
    required this.amountHidden,
    required this.onTabChange,
    required this.onShowAll,
  });

  bool get _isLoss => activeTab == '亏损TOP5';

  @override
  Widget build(BuildContext context) {
    final progressColor = _isLoss ? const Color(0xFF07B361) : const Color(0xFFFF5B69);
    final valueColor = _isLoss
        ? (isDark ? const Color(0xFF10B4A1) : const Color(0xFF07B361))
        : (isDark ? AppColors.upColor : const Color(0xFFFF5B69));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), // mr-4 ml-4 mt-4
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(6), // 12rpx
      ),
      child: Column(
        children: [
          CurveSectionTitle(
            isDark: isDark,
            title: title,
            action: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onShowAll,
              child: Row(
                children: [
                  Text('全部',
                      style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFD9B19B), height: 1)),
                  Icon(Icons.chevron_right, size: 18, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFBF633A)),
                ],
              ),
            ),
          ),
          // ===== Tab =====
          Container(
            margin: const EdgeInsets.fromLTRB(10, 5, 10, 0), // 0 20rpx, mt 10rpx
            height: 25, // 50rpx
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFD9DDE8), width: 0.5),
              borderRadius: BorderRadius.circular(3), // 6rpx
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTabChange(tab),
                        child: Container(
                          alignment: Alignment.center,
                          color: activeTab == tab
                              ? (isDark ? AppColors.upColor : const Color(0xFF5D7EF6))
                              : (isDark ? const Color(0xFF282828) : Colors.white),
                          child: Text(
                            tab,
                            style: AppTextStyles.cn(
                              12,
                              color: activeTab == tab
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFFB8BDCB)),
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ===== 列表 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 9), // 12rpx 20rpx 18rpx
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 7), // 16rpx 0 14rpx
                    decoration: BoxDecoration(
                      border: i == items.length - 1
                          ? null
                          : Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F3F7), width: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 排名
                        Container(
                          width: 24, // 48rpx
                          padding: const EdgeInsets.only(top: 2), // 4rpx
                          alignment: Alignment.center,
                          child: i > 2
                              ? Text('${i + 1}',
                                  style: AppTextStyles.num(15, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8F96A8), height: 1))
                              : _Medal(index: i + 1, color: medalColors[i]),
                        ),
                        // 内容
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5), // 10rpx
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        items[i].name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : const Color(0xFF363D53), height: 18 / 13),
                                      ),
                                    ),
                                    const SizedBox(width: 9), // 18rpx
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 56), // 112rpx
                                      child: Text(
                                        amountHidden ? '******' : items[i].value,
                                        textAlign: TextAlign.right,
                                        style: AppTextStyles.num(14, color: valueColor, height: 18 / 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6), // 12rpx
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: SizedBox(
                                    height: 3, // u-line-progress height=6rpx
                                    child: LinearProgressIndicator(
                                      value: (items[i].percentage.clamp(0, 100)) / 100,
                                      backgroundColor: const Color(0xFFF3F5FA),
                                      valueColor: AlwaysStoppedAnimation(progressColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 前三名奖牌（medal-filled + 数字覆盖）
class _Medal extends StatelessWidget {
  final int index;
  final Color color;

  const _Medal({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(AppIcons.goldMedal, size: 26, color: color),
          Positioned(
            top: 5, // 10rpx
            left: 0,
            right: 0,
            child: Center(
              child: Text('$index',
                  style: AppTextStyles.num(9, color: Colors.white, weight: FontWeight.w700, height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
