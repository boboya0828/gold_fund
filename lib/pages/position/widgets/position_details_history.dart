import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 收益（阶段/月度/季度/半年/年度 对照沪深300）卡片
/// uni-app 对应: position-details.vue 的第一个 .history-card
class PositionDetailsStageCard extends StatelessWidget {
  final bool isDark;
  final List<Map<String, String>> tabs; // [{label, value}]
  final String activeTab;
  final ValueChanged<String> onTabChange;
  final List<PdStageRow> rows;
  final VoidCallback onMore;

  const PositionDetailsStageCard({
    super.key,
    required this.isDark,
    required this.tabs,
    required this.activeTab,
    required this.onTabChange,
    required this.rows,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final headColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFA6A6A6);
    final rowColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final divider = Border(top: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF0F0F0), width: 0.5));

    Widget cell(String t, {Color? color, bool left = false, bool right = false}) => Expanded(
          child: Text(t,
              textAlign: left ? TextAlign.left : (right ? TextAlign.right : TextAlign.center),
              style: AppTextStyles.num(13, color: color ?? rowColor)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 9), // 18rpx
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 4), // 20rpx 18rpx 8rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(11), // 22rpx
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('收益', style: AppTextStyles.cn(15, color: titleColor, weight: FontWeight.w700)),
          GestureDetector(
            onTap: onMore,
            child: Row(children: [
              Text('更多', style: AppTextStyles.cn(11, color: headColor)),
              Icon(Icons.chevron_right, size: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF777777)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        // 阶段 tabs
        Row(children: [
          for (final t in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onTabChange(t['value']!),
                behavior: HitTestBehavior.opaque,
                child: Column(children: [
                  Text(t['label']!,
                      style: AppTextStyles.cn(12,
                          color: activeTab == t['value'] ? titleColor : headColor,
                          weight: activeTab == t['value'] ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 3),
                  Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: activeTab == t['value'] ? AppColors.upColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        // 表头
        Row(children: [
          Expanded(child: Text('周期', style: AppTextStyles.cn(11, color: headColor, height: 1.4))),
          Expanded(child: Center(child: Text('本基金', style: AppTextStyles.cn(11, color: headColor, height: 1.4)))),
          Expanded(child: Center(child: Text('沪深300', style: AppTextStyles.cn(11, color: headColor, height: 1.4)))),
          Expanded(
              child: Align(
                  alignment: Alignment.centerRight, child: Text('超额收益', style: AppTextStyles.cn(11, color: headColor, height: 1.4)))),
        ]),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3), // 22rpx 6rpx
            decoration: BoxDecoration(border: divider),
            child: Row(children: [
              Expanded(child: Text(r.date, style: AppTextStyles.num(13, color: rowColor))),
              cell(r.change, color: r.changeRaw == null ? rowColor : pdProfitColor(r.changeRaw)),
              cell(r.hs300, color: r.hs300Raw == null ? rowColor : pdProfitColor(r.hs300Raw)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(r.excess,
                      style: AppTextStyles.num(13, color: r.excessRaw == null ? rowColor : pdProfitColor(r.excessRaw))),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// 持仓详情 — 历史净值/历史克价 卡片
/// uni-app 对应: position-details.vue 的第二个 .history-card
class PositionDetailsHistoryCard extends StatelessWidget {
  final bool isDark;
  final String title; // 历史净值 / 历史克价
  final String unitLabel; // 单位净值 / 克价
  final List<PdHistoryRow> rows;
  final VoidCallback onMore;

  const PositionDetailsHistoryCard({
    super.key,
    required this.isDark,
    required this.title,
    required this.unitLabel,
    required this.rows,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final headColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFA6A6A6);
    final rowColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final divider = Border(top: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF0F0F0), width: 0.5));

    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: AppTextStyles.cn(15, color: titleColor, weight: FontWeight.w700)),
          GestureDetector(
            onTap: onMore,
            child: Row(children: [
              Text('更多', style: AppTextStyles.cn(11, color: headColor)),
              Icon(Icons.chevron_right, size: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF777777)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('日期', style: AppTextStyles.cn(11, color: headColor, height: 1.4))),
          Expanded(child: Center(child: Text(unitLabel, style: AppTextStyles.cn(11, color: headColor, height: 1.4)))),
          Expanded(
              child: Align(alignment: Alignment.centerRight, child: Text('涨幅', style: AppTextStyles.cn(11, color: headColor, height: 1.4)))),
        ]),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
            decoration: BoxDecoration(border: divider),
            child: Row(children: [
              Expanded(child: Text(r.date, style: AppTextStyles.num(13, color: rowColor))),
              Expanded(child: Center(child: Text(r.unitValue, style: AppTextStyles.num(13, color: rowColor)))),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(r.change, style: AppTextStyles.num(13, color: pdProfitColor(r.changeRaw))),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
