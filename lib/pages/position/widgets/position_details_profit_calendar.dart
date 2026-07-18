import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 我的收益（收益日历 + 分析框）
/// uni-app 对应: position-details.vue 的 .curve-calendar / .calendar-* / .analysis-box
class PositionDetailsProfitCalendar extends StatelessWidget {
  final bool isDark;
  final bool showPercent;
  final VoidCallback onToggleMode;

  final List<String> views; // ['日','月','年']
  final String activeView;
  final ValueChanged<String> onViewChange;

  final String switchLabel;
  final VoidCallback onOpenMonthPicker;

  // 日视图
  final List<PdCalendarDay> days;
  final int? selectedDay;
  final ValueChanged<PdCalendarDay> onDayTap;

  // 月/年视图
  final List<PdCalendarCell> monthCells;
  final List<PdCalendarCell> yearCells;
  final ValueChanged<PdCalendarCell> onMonthTap;
  final ValueChanged<PdCalendarCell> onYearTap;

  final String footerLabel;
  final String footerProfitText;

  // 分析框（summary 原值）
  final Map<String, dynamic>? summary;

  const PositionDetailsProfitCalendar({
    super.key,
    required this.isDark,
    required this.showPercent,
    required this.onToggleMode,
    required this.views,
    required this.activeView,
    required this.onViewChange,
    required this.switchLabel,
    required this.onOpenMonthPicker,
    required this.days,
    required this.selectedDay,
    required this.onDayTap,
    required this.monthCells,
    required this.yearCells,
    required this.onMonthTap,
    required this.onYearTap,
    required this.footerLabel,
    required this.footerProfitText,
    required this.summary,
  });

  static const _weekDays = ['一', '二', '三', '四', '五'];

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final subColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFA6A6A6);
    final cellBg = isDark ? const Color(0xFF282828) : const Color(0xFFFAFAFA);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 15, 0, 10), // 30rpx 24rpx 20rpx
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(width: 3, height: 14, decoration: BoxDecoration(color: kPdChartRed, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('收益日历', style: AppTextStyles.cn(14, color: textColor, weight: FontWeight.w700)),
                ]),
                GestureDetector(
                  onTap: onToggleMode,
                  child: Row(children: [
                    Icon(Icons.swap_horiz, size: 16, color: kPdChartRed),
                    const SizedBox(width: 2),
                    Text(showPercent ? '切换为收益' : '切换为收益率', style: AppTextStyles.cn(11, color: kPdChartRed)),
                  ]),
                ),
              ],
            ),
          ),
          // 工具栏：日/月/年 + 月份选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F6),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(children: [
                  for (final v in views)
                    GestureDetector(
                      onTap: () => onViewChange(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeView == v ? AppColors.upColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(v,
                            style: AppTextStyles.cn(11,
                                color: activeView == v ? Colors.white : subColor)),
                      ),
                    ),
                ]),
              ),
              GestureDetector(
                onTap: onOpenMonthPicker,
                child: Row(children: [
                  Text(switchLabel, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : const Color(0xFF4E556A))),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4E556A)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activeView == '日') ...[
            // 星期头
            Row(children: [
              for (final w in _weekDays)
                Expanded(child: Center(child: Text(w, style: AppTextStyles.cn(11, color: subColor)))),
            ]),
            const SizedBox(height: 4),
            // 日格子（5 列，仅工作日）
            for (var r = 0; r < (days.length + 4) ~/ 5; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  for (var c = 0; c < 5; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: c == 0 ? 0 : 4),
                        child: r * 5 + c < days.length ? _dayCell(days[r * 5 + c]) : const SizedBox(height: 44),
                      ),
                    ),
                ]),
              ),
          ] else if (activeView == '月')
            _cellGrid(monthCells, (c) => '${c.keyValue}月', onMonthTap)
          else
            _cellGrid(yearCells, (c) => '${c.keyValue}', onYearTap),
          // 底部累计
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$footerLabel累计收益：', style: AppTextStyles.cn(11, color: subColor)),
              Text(footerProfitText, style: AppTextStyles.num(12, color: kPdRiseColor, weight: FontWeight.w600)),
            ]),
          ),
          // 分析框
          _analysisBox(cellBg, textColor, subColor),
        ],
      ),
    );
  }

  Widget _dayCell(PdCalendarDay d) {
    final isRise = d.type == 'rise';
    final isLoss = d.type == 'loss';
    Color bg = Colors.transparent;
    if (isRise) bg = isDark ? const Color(0xFF3A242A) : const Color(0xFFFDE7E8);
    if (isLoss) bg = isDark ? const Color(0xFF1E332C) : const Color(0xFFD8F4E7);
    final selected = selectedDay != null && selectedDay == d.day && (isRise || isLoss);
    final profitColor = isRise ? kPdRiseColor : const Color(0xFF10A86D);
    final dayColor = isDark ? AppColors.darkText : const Color(0xFF333333);

    return GestureDetector(
      onTap: () => onDayTap(d),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: profitColor, width: 1) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.isToday ? '今' : (d.day?.toString() ?? ''),
                style: AppTextStyles.cn(10,
                    color: d.isToday ? kPdRiseColor : (d.day == null ? Colors.transparent : dayColor), height: 1.0)),
            if (d.value.isNotEmpty || d.percentValue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  showPercent ? d.percentValue : d.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.num(9, color: profitColor, height: 1.0),
                ),
              ),
            if (d.tag.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(d.tag, style: AppTextStyles.cn(9, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF999999), height: 1.0)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellGrid(List<PdCalendarCell> cells, String Function(PdCalendarCell) titleOf, ValueChanged<PdCalendarCell> onTap) {
    final cellBg = isDark ? const Color(0xFF282828) : const Color(0xFFFAFAFA);
    final textColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.1,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final c = cells[i];
        final raw = double.tryParse(c.value.replaceAll('+', ''));
        final valColor = (raw ?? 0) >= 0 ? kPdRiseColor : kPdFallColor;
        return GestureDetector(
          onTap: () => onTap(c),
          child: Container(
            decoration: BoxDecoration(
              color: c.isActive ? AppColors.upColor : cellBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(titleOf(c), style: AppTextStyles.cn(12, color: c.isActive ? Colors.white : textColor)),
                if (c.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(c.value, style: AppTextStyles.num(11, color: c.isActive ? Colors.white : valColor)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _analysisBox(Color bg, Color textColor, Color subColor) {
    final s = summary;
    String signed(dynamic v) {
      final n = v is num ? v.toDouble() : 0.0;
      return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}';
    }

    String dateOf(dynamic v) => v == null ? '--' : '$v'.substring(0, '$v'.length >= 10 ? 10 : '$v'.length);
    String daysOf(dynamic v) => v == null ? '--' : '$v天';
    String pctOf(dynamic rise, dynamic total) {
      final r = rise is num ? rise : null;
      final t = total is num ? total : null;
      if (r == null || t == null || t == 0) return '--';
      return '${(r / t * 100).round()}%';
    }

    Widget item(String label, String value, String sub, {Color? valueColor}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label, style: AppTextStyles.cn(11, color: subColor)),
              const SizedBox(width: 6),
              Text(value, style: AppTextStyles.num(13, color: valueColor ?? textColor, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(sub, style: AppTextStyles.cn(11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB7ABAB))),
          ]),
        );
    Widget divider() => Container(width: 0.5, height: 30, color: isDark ? AppColors.darkBorder : const Color(0xFFEEEEEE));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(children: [
          item('赚最大', s == null ? '--' : signed(s['maxProfit']), s == null ? '--' : dateOf(s['maxProfitDate']),
              valueColor: const Color(0xFFE45A6F)),
          divider(),
          const SizedBox(width: 12),
          item('亏最大', s == null ? '--' : signed(s['minProfit']), s == null ? '--' : dateOf(s['minProfitDate']),
              valueColor: const Color(0xFF10A86D)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          item('上涨天数', s == null ? '--' : daysOf(s['riseDays']), '占${s == null ? '--' : pctOf(s['riseDays'], s['totalDays'])}'),
          divider(),
          const SizedBox(width: 12),
          item('下跌天数', s == null ? '--' : daysOf(s['fallDays']), '占${s == null ? '--' : pctOf(s['fallDays'], s['totalDays'])}'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          item('最长连涨', s == null ? '--' : daysOf(s['maxConsecutiveRise']), s?['maxConsecutiveRiseRange']?.toString() ?? '--'),
          divider(),
          const SizedBox(width: 12),
          item('最长连跌', s == null ? '--' : daysOf(s['maxConsecutiveFall']), s?['maxConsecutiveFallRange']?.toString() ?? '--'),
        ]),
      ]),
    );
  }
}
