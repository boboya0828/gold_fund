import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 顶部资产概览卡（hero-card）
/// uni-app 对应: pages/index/fund/position-details.vue 的 .hero-card
class PositionDetailsHeroCard extends StatelessWidget {
  final bool isDark;
  final String shortName;
  final String symbol;
  final String assetTypeLabel;
  final List<PdMetricItem> summaryTop;

  /// 是否显示账本选择下拉（来自全部账本且账本数 > 1）
  final bool showBookSelect;
  final String selectedBookName;
  final bool bookDropdownOpen;
  final List<PdBookTab> bookTabs;
  final int selectedBookId;
  final VoidCallback onToggleBookDropdown;
  final ValueChanged<PdBookTab> onSelectBook;

  /// 持仓 9 指标（无持仓时为空）
  final List<PdMetricItem> positionMetrics;

  const PositionDetailsHeroCard({
    super.key,
    required this.isDark,
    required this.shortName,
    required this.symbol,
    required this.assetTypeLabel,
    required this.summaryTop,
    required this.showBookSelect,
    required this.selectedBookName,
    required this.bookDropdownOpen,
    required this.bookTabs,
    required this.selectedBookId,
    required this.onToggleBookDropdown,
    required this.onSelectBook,
    required this.positionMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF222844);
    final metaColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF999999);
    final metricBg = isDark ? const Color(0xFF282828) : const Color(0xFFFBF9F9);
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF9A9A9A);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13), // 28rpx 30rpx 26rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(7), // 14rpx
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基金名称
          Text(shortName, style: AppTextStyles.cn(16, color: titleColor, weight: FontWeight.w700, height: 1.25)),
          // 代码 | 类型
          Padding(
            padding: const EdgeInsets.only(top: 6), // 12rpx
            child: Row(children: [
              Text(symbol.isEmpty ? '000001' : symbol, style: AppTextStyles.num(12, color: metaColor)),
              Container(
                width: 0.5,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 9), // 18rpx gap
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFFD8D8D8),
              ),
              Text(assetTypeLabel, style: AppTextStyles.cn(12, color: metaColor)),
            ]),
          ),
          // 顶部 3 指标
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < summaryTop.length; i++)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summaryTop[i].value,
                          style: AppTextStyles.num(
                            i == 0 ? 23 : 17, // 46rpx / 34rpx
                            color: summaryTop[i].valueColor ?? titleColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10), // 20rpx
                        Text(summaryTop[i].label,
                            style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA2A2A2), height: 1.0)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 账本选择
          if (showBookSelect)
            Padding(
              padding: const EdgeInsets.only(top: 7), // 14rpx
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onToggleBookDropdown,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 17, // 34rpx
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(selectedBookName,
                            style: AppTextStyles.cn(12, color: AppColors.upColor, weight: FontWeight.w500, height: 1.0)),
                        Icon(bookDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 12, color: AppColors.upColor),
                      ]),
                    ),
                  ),
                  if (bookDropdownOpen)
                    Container(
                      width: 120, // 240rpx
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 180), // 360rpx
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282B32) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: bookTabs.length,
                        itemBuilder: (_, i) {
                          final item = bookTabs[i];
                          final active = item.bookId == selectedBookId;
                          return GestureDetector(
                            onTap: () => onSelectBook(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              color: active ? (isDark ? const Color(0xFF3A3E48) : const Color(0xFFFFF3F4)) : Colors.transparent,
                              child: Text(item.bookName,
                                  style: AppTextStyles.cn(12,
                                      color: active ? AppColors.upColor : (isDark ? AppColors.darkText : AppColors.lightText))),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          // 持仓 9 指标
          if (positionMetrics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7, // 14rpx
                  crossAxisSpacing: 6, // 12rpx
                  childAspectRatio: 1.9,
                ),
                itemCount: positionMetrics.length,
                itemBuilder: (_, i) {
                  final m = positionMetrics[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(5, 10, 5, 9), // 20rpx 10rpx 18rpx
                    decoration: BoxDecoration(color: metricBg, borderRadius: BorderRadius.circular(8)), // 16rpx
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.label, style: AppTextStyles.cn(11, color: labelColor, height: 1.0)), // 22rpx
                        const SizedBox(height: 6), // 12rpx
                        Text(
                          m.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.num(14, color: m.valueColor ?? (isDark ? AppColors.darkText : AppColors.lightText),
                              weight: FontWeight.w700, height: 1.2), // 28rpx
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
