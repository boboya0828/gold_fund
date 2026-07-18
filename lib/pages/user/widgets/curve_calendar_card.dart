import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';

/// 盈亏日历视图
enum CurveCalendarView { day, month, year }

/// 日历日格子数据
class CurveCalendarDay {
  final int? day; // null → 前置空白格
  final String value; // '+12.34' / ''
  final String percentValue; // '+1.23%' / ''
  final String type; // '' / 'rise' / 'loss' / 'strong-rise'
  final String tag; // '休' / ''
  final bool isToday;

  const CurveCalendarDay({
    this.day,
    this.value = '',
    this.percentValue = '',
    this.type = '',
    this.tag = '',
    this.isToday = false,
  });
}

/// 月/年格子数据
class CurveCalendarPeriod {
  final int period; // month(1-12) / year
  final String title; // '5月' / '2025'
  final String value;
  final String percentValue;
  final String type; // '' / 'rise' / 'loss'
  final bool isActive;

  const CurveCalendarPeriod({
    required this.period,
    required this.title,
    this.value = '',
    this.percentValue = '',
    this.type = '',
    this.isActive = false,
  });

  bool get hasValue => value.isNotEmpty || percentValue.isNotEmpty;
}

/// 盈亏日历卡 — 1:1 复刻 uni-app curve.vue `.curve-calendar`
/// 含标题行(切换收益/收益率)、日/月/年视图切换、月份选择入口、底部累计
class CurveCalendarCard extends StatelessWidget {
  final bool isDark;
  final bool showPercent;
  final CurveCalendarView view;
  final String switchLabel; // '2025年5月' / '2025年' / '全部'
  final List<CurveCalendarDay> days;
  final int? selectedDay;
  final List<CurveCalendarPeriod> monthCells;
  final List<CurveCalendarPeriod> yearCells;
  final String footerLabel; // '5月' / '2025年'
  final String footerValue;
  final String Function(String) maskAmount;

  final VoidCallback onToggleMode;
  final ValueChanged<CurveCalendarView> onViewChange;
  final VoidCallback onOpenPicker;
  final ValueChanged<CurveCalendarDay> onDayTap;
  final ValueChanged<CurveCalendarPeriod> onMonthTap;
  final ValueChanged<CurveCalendarPeriod> onYearTap;

  static const weekDays = ['一', '二', '三', '四', '五'];

  const CurveCalendarCard({
    super.key,
    required this.isDark,
    required this.showPercent,
    required this.view,
    required this.switchLabel,
    required this.days,
    required this.selectedDay,
    required this.monthCells,
    required this.yearCells,
    required this.footerLabel,
    required this.footerValue,
    required this.maskAmount,
    required this.onToggleMode,
    required this.onViewChange,
    required this.onOpenPicker,
    required this.onDayTap,
    required this.onMonthTap,
    required this.onYearTap,
  });

  // ===== 颜色 =====
  Color get _riseBg => isDark ? const Color(0xFF322329) : const Color(0xFFFDE7E8);
  Color get _lossBg => isDark ? const Color(0xFF22302E) : const Color(0xFFD8F4E7);
  Color get _strongRiseBg => isDark ? AppColors.upColor : const Color(0xFFFF4A53);
  Color get _selectedLossBg => isDark ? const Color(0xFF00ADA0) : const Color(0xFF07B361);
  Color get _riseText => isDark ? AppColors.upColor : const Color(0xFFF15E63);
  Color get _lossText => isDark ? const Color(0xFF10B4A1) : const Color(0xFF10A86D);

  @override
  Widget build(BuildContext context) {
    final titleActionColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFD9B19B);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), // 32rpx 32rpx 0
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(9), // 18rpx
        boxShadow: isDark
            ? null
            : [BoxShadow(color: const Color(0xFF45527C).withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // ===== 标题行 =====
          CurveSectionTitle(
            isDark: isDark,
            title: '盈亏日历',
            action: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleMode,
              child: Row(
                children: [
                  Icon(AppIcons.switchIcon, size: 18, color: isDark ? AppColors.upColor : const Color(0xFFC76E33)),
                  const SizedBox(width: 5), // 10rpx
                  Text(showPercent ? '切换为收益' : '切换为收益率',
                      style: AppTextStyles.cn(12, color: titleActionColor, height: 1)),
                ],
              ),
            ),
          ),
          // ===== 工具行 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), // 0 24rpx 16rpx
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildViewSwitch(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenPicker,
                  child: Row(
                    children: [
                      Text(switchLabel,
                          style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF4D5367), weight: FontWeight.w500)),
                      const SizedBox(width: 4), // 8rpx
                      Icon(Icons.keyboard_arrow_down, size: 14,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4E556A)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ===== 视图主体 =====
          if (view == CurveCalendarView.day) _buildDayView(),
          if (view == CurveCalendarView.month) _buildMonthView(),
          if (view == CurveCalendarView.year) _buildYearView(),
          // ===== 底部累计 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 6), // 22rpx 24rpx 12rpx
            child: Row(
              children: [
                Text('$footerLabel累计${showPercent ? '收益率' : '收益'}',
                    style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4D5367))),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    maskAmount(footerValue),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.num(15, color: _riseText, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitch() {
    const tabs = ['日', '月', '年'];
    const views = [CurveCalendarView.day, CurveCalendarView.month, CurveCalendarView.year];
    return Container(
      padding: const EdgeInsets.all(3), // 6rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFEFF1F5),
        borderRadius: BorderRadius.circular(999),
        border: isDark ? null : Border.all(color: const Color(0xFFE6EAF2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onViewChange(views[i]),
              child: Container(
                constraints: const BoxConstraints(minWidth: 27), // 54rpx
                height: 23, // 46rpx
                padding: const EdgeInsets.symmetric(horizontal: 9), // 18rpx
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: view == views[i]
                      ? (isDark ? AppColors.upColor : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: view == views[i] && !isDark
                      ? [BoxShadow(color: const Color(0xFF5C6AC4).withValues(alpha: 0.16), blurRadius: 7, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Text(
                  tabs[i],
                  style: AppTextStyles.cn(
                    12,
                    color: view == views[i]
                        ? (isDark ? Colors.white : const Color(0xFF4F6FEA))
                        : (isDark ? AppColors.darkTextSecondary : const Color(0xFF8F97AA)),
                    weight: view == views[i] ? FontWeight.w600 : FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== 日视图 =====
  Widget _buildDayView() {
    final borderColor = isDark ? Colors.transparent : const Color(0xFFF6F7FA);
    final rows = <List<CurveCalendarDay>>[
      for (var i = 0; i < days.length; i += 5) days.sublist(i, i + 5 > days.length ? days.length : i + 5),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2), // 0 4rpx
      child: Column(
        children: [
          // 星期头
          Container(
            height: 25, // 50rpx
            color: isDark ? const Color(0xFF282828) : Colors.transparent,
            child: Row(
              children: [
                for (final w in weekDays)
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: AppTextStyles.cn(11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA5ABBC), height: 1)),
                    ),
                  ),
              ],
            ),
          ),
          // 日历主体
          Container(
            decoration: BoxDecoration(
              border: isDark
                  ? null
                  : const Border(
                      top: BorderSide(color: Color(0xFFF1F3F7), width: 0.5),
                      bottom: BorderSide(color: Color(0xFFF1F3F7), width: 0.5),
                    ),
            ),
            child: Column(
              children: [
                for (var r = 0; r < rows.length; r++)
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var c = 0; c < 5; c++)
                          Expanded(
                            child: c < rows[r].length
                                ? _buildDayCell(rows[r][c], showRightBorder: c < 4 && !isDark, showBottomBorder: r < rows.length - 1 && !isDark, borderColor: borderColor)
                                : const SizedBox.shrink(),
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

  Widget _buildDayCell(CurveCalendarDay day, {required bool showRightBorder, required bool showBottomBorder, required Color borderColor}) {
    final isEmpty = day.day == null;
    final noValue = !isEmpty && day.value.isEmpty && day.tag.isEmpty;
    final isSelected = !isEmpty && selectedDay == day.day && day.type.isNotEmpty;

    Color bg;
    if (isDark) {
      if (isEmpty || noValue) {
        bg = const Color(0xFF242529);
      } else if (isSelected) {
        bg = day.type == 'loss' ? _selectedLossBg : _strongRiseBg;
      } else if (day.type == 'strong-rise') {
        bg = _strongRiseBg;
      } else if (day.type == 'rise') {
        bg = _riseBg;
      } else if (day.type == 'loss') {
        bg = _lossBg;
      } else {
        bg = const Color(0xFF242529);
      }
    } else {
      if (isSelected) {
        bg = day.type == 'loss' ? _selectedLossBg : _strongRiseBg;
      } else if (day.type == 'strong-rise') {
        bg = _strongRiseBg;
      } else if (day.type == 'rise') {
        bg = _riseBg;
      } else if (day.type == 'loss') {
        bg = _lossBg;
      } else {
        bg = Colors.white;
      }
    }

    final strong = day.type == 'strong-rise' || isSelected;
    final dayTextColor = strong ? Colors.white : (isDark ? AppColors.darkText : const Color(0xFF373737));
    final profitColor = strong
        ? Colors.white
        : (day.type == 'loss' ? _lossText : _riseText);

    final displayValue = showPercent ? (day.percentValue.isEmpty ? '--' : day.percentValue) : day.value;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap(day),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56), // 112rpx
        padding: noValue ? EdgeInsets.zero : const EdgeInsets.fromLTRB(4, 9, 4, 6), // 18rpx 8rpx 12rpx
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: showRightBorder ? BorderSide(color: borderColor, width: 0.5) : BorderSide.none,
            bottom: showBottomBorder ? BorderSide(color: borderColor, width: 0.5) : BorderSide.none,
          ),
        ),
        child: isEmpty
            ? const SizedBox.shrink()
            : Column(
                mainAxisAlignment: noValue ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Text(
                    day.isToday ? '今' : '${day.day}',
                    style: AppTextStyles.num(day.isToday ? 16 : 14, color: dayTextColor, height: 1),
                  ),
                  if (day.value.isNotEmpty || day.percentValue.isNotEmpty) ...[
                    const SizedBox(height: 6), // 12rpx
                    Text(
                      maskAmount(displayValue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.num(12, color: profitColor, height: 1),
                    ),
                  ],
                  if (day.tag.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(day.tag, style: AppTextStyles.cn(13, color: dayTextColor, height: 1)),
                  ],
                ],
              ),
      ),
    );
  }

  // ===== 月/年视图 =====
  Widget _buildMonthView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), // 20rpx 24rpx
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4, // 8rpx
        crossAxisSpacing: 4,
        childAspectRatio: _gridRatio(4, 47), // cell 高 94rpx
        children: [for (final m in monthCells) _buildPeriodCell(m, onMonthTap)],
      ),
    );
  }

  Widget _buildYearView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: _gridRatio(3, 55), // cell 高 110rpx
        children: [for (final y in yearCells) _buildPeriodCell(y, onYearTap)],
      ),
    );
  }

  // GridView 需要静态宽高比：卡片宽 = 屏宽 - 32(外边距) - 24(内边距)
  double _gridRatio(int cols, double cellHeight) {
    // 屏宽按 375 设计宽度估算（页面本身按 375 设计稿等比，此处只是格子宽高比的近似）
    const screenW = 375.0;
    final gridW = screenW - 32 - 24;
    final cellW = (gridW - (cols - 1) * 4) / cols;
    return cellW / cellHeight;
  }

  Widget _buildPeriodCell(CurveCalendarPeriod cell, ValueChanged<CurveCalendarPeriod> onTap) {
    Color bg;
    if (!cell.hasValue) {
      bg = isDark ? const Color(0xFF242529) : const Color(0xFFF5F6F8);
    } else if (cell.isActive) {
      bg = cell.type == 'loss' ? _selectedLossBg : _strongRiseBg;
    } else if (cell.type == 'loss') {
      bg = _lossBg;
    } else {
      bg = _riseBg;
    }

    final active = cell.isActive;
    final titleColor = active ? Colors.white : (isDark ? AppColors.darkText : const Color(0xFF7C8295));
    final valueColor = active ? Colors.white : (cell.type == 'loss' ? _lossText : _riseText);
    final displayValue = showPercent ? (cell.percentValue.isEmpty ? '--' : cell.percentValue) : cell.value;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cell.hasValue ? () => onTap(cell) : null,
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)), // 8rpx
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(cell.title, style: AppTextStyles.num(12, color: titleColor, height: 1)),
            if (cell.hasValue) ...[
              const SizedBox(height: 5), // 10rpx
              Text(
                maskAmount(displayValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.num(12, color: valueColor, height: 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 区块标题（竖条 + 标题 + 右侧动作）— `.curve-title`
class CurveSectionTitle extends StatelessWidget {
  final bool isDark;
  final String title;
  final Widget? action;

  const CurveSectionTitle({super.key, required this.isDark, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 15, 12, 10), // 30rpx 24rpx 20rpx
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3, // 6rpx
                height: 13, // 26rpx
                margin: const EdgeInsets.only(right: 8), // 16rpx
                decoration: BoxDecoration(
                  color: isDark ? AppColors.upColor : const Color(0xFFBF633A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(title,
                  style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF2D211D), weight: FontWeight.w700, height: 1)),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}
