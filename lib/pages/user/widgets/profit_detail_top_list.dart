import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';

/// 盈亏明细条目
class ProfitDetailItem {
  final String name;
  final String value; // '+12.34' / '-12.34'
  final int percentage; // 0-100

  const ProfitDetailItem({required this.name, required this.value, required this.percentage});
}

/// 盈亏明细 TOP5 列表 — 1:1 复刻 uni-app pages/user/profit-detail.vue
/// 盈利TOP5/亏损TOP5 Tab + 奖牌排行 + 进度条
class ProfitDetailTopList extends StatelessWidget {
  final bool isDark;
  final String activeTab; // 'profit' / 'loss'
  final List<ProfitDetailItem> items;
  final ValueChanged<String> onTabChange;

  static const medalColors = [Color(0xFFFFBE37), Color(0xFFC7D1DD), Color(0xFFFF944D)];

  const ProfitDetailTopList({
    super.key,
    required this.isDark,
    required this.activeTab,
    required this.items,
    required this.onTabChange,
  });

  bool get _isLoss => activeTab == 'loss';

  @override
  Widget build(BuildContext context) {
    final progressColor = _isLoss ? const Color(0xFF07B361) : const Color(0xFFFF5B69);
    final valueColor = _isLoss
        ? (isDark ? const Color(0xFF10B4A1) : const Color(0xFF07B361))
        : (isDark ? AppColors.upColor : const Color(0xFFFF5B69));

    return Column(
      children: [
        // ===== Tab =====
        Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 0), // 16rpx 20rpx 0
          height: 25, // 50rpx
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFD9DDE8),
              width: 0.5, // 1rpx
            ),
            borderRadius: BorderRadius.circular(3), // 6rpx
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                _tab('盈利TOP5', 'profit', isDark),
                _tab('亏损TOP5', 'loss', isDark),
              ],
            ),
          ),
        ),
        // ===== 列表 =====
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 9), // 12rpx 20rpx 18rpx
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30), // 60rpx
                  child: Center(
                    child: Text(
                      '暂无数据',
                      style: AppTextStyles.cn(13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB8BDCB)),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) _item(i, isDark, valueColor, progressColor),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tab(String label, String value, bool isDark) {
    final active = activeTab == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabChange(value),
        child: Container(
          alignment: Alignment.center,
          color: active
              ? (isDark ? AppColors.upColor : const Color(0xFF5D7EF6))
              : (isDark ? const Color(0xFF282828) : Colors.white),
          child: Text(
            label,
            style: AppTextStyles.cn(
              12,
              color: active
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFFB8BDCB)),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int index, bool isDark, Color valueColor, Color progressColor) {
    final item = items[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 7), // 16rpx 0 14rpx
      decoration: BoxDecoration(
        border: index == items.length - 1
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F3F7),
                  width: 0.5, // 1rpx
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排名
          Container(
            width: 24, // 48rpx
            padding: const EdgeInsets.only(top: 2), // 4rpx
            alignment: Alignment.center,
            child: index > 2
                ? Text(
                    '${index + 1}',
                    style: AppTextStyles.num(
                      15, // 30rpx
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8F96A8),
                      height: 1,
                    ),
                  )
                : _Medal(index: index + 1, color: medalColors[index]),
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
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cn(
                            13, // 26rpx
                            color: isDark ? AppColors.darkText : const Color(0xFF363D53),
                            height: 18 / 13, // line-height 36rpx
                          ),
                        ),
                      ),
                      const SizedBox(width: 9), // 18rpx
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 56), // 112rpx
                        child: Text(
                          item.value,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.num(14, color: valueColor, height: 18 / 14), // 28rpx / 36rpx
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6), // 12rpx
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 3, // u-line-progress height=6(rpx)
                      child: LinearProgressIndicator(
                        value: (item.percentage.clamp(0, 100)) / 100,
                        backgroundColor: const Color(0xFFF3F5FA), // inactiveColor（明暗同色）
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
    );
  }
}

/// 前三名奖牌（uni-icons medal-filled + 数字覆盖）
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
              child: Text(
                '$index',
                style: AppTextStyles.num(9, color: Colors.white, weight: FontWeight.w700, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
