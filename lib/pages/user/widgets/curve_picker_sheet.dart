import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 年月/年份滚轮选择弹层 — 1:1 复刻 uni-app curve.vue 的 uni-popup + picker-view
/// 取消/确定头部 + 88rpx(44px) 行高滚轮
class CurvePickerSheet extends StatefulWidget {
  final bool isDark;
  final String title; // '选择年月' / '选择年份'
  final List<int> yearOptions;
  final bool withMonth;
  final int initialYearIndex;
  final int initialMonthIndex; // 0-11, withMonth 时有效

  const CurvePickerSheet({
    super.key,
    required this.isDark,
    required this.title,
    required this.yearOptions,
    required this.withMonth,
    required this.initialYearIndex,
    required this.initialMonthIndex,
  });

  /// 弹出年月选择器；返回 (year, month?)，取消返回 null
  static Future<(int, int?)?> show(
    BuildContext context, {
    required bool isDark,
    required List<int> yearOptions,
    required bool withMonth,
    required int initialYear,
    int initialMonth = 1,
  }) {
    final yearIndex = yearOptions.indexOf(initialYear);
    return showModalBottomSheet<(int, int?)?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CurvePickerSheet(
        isDark: isDark,
        title: withMonth ? '选择年月' : '选择年份',
        yearOptions: yearOptions,
        withMonth: withMonth,
        initialYearIndex: yearIndex >= 0 ? yearIndex : 0,
        initialMonthIndex: (initialMonth - 1).clamp(0, 11),
      ),
    );
  }

  @override
  State<CurvePickerSheet> createState() => _CurvePickerSheetState();
}

class _CurvePickerSheetState extends State<CurvePickerSheet> {
  late int _yearIndex = widget.initialYearIndex;
  late int _monthIndex = widget.initialMonthIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF282828) : Colors.white;
    final actionColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8F97AA);
    final confirmColor = isDark ? AppColors.upColor : const Color(0xFF4F6FEA);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF2F3547);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), // 24rpx
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Container(
              height: 48, // 96rpx
              padding: const EdgeInsets.symmetric(horizontal: 16), // 32rpx
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F3F7), width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('取消', style: AppTextStyles.cn(14, color: actionColor)),
                    ),
                  ),
                  Text(widget.title, style: AppTextStyles.cn(15, color: titleColor, weight: FontWeight.w600)),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop((
                      widget.yearOptions[_yearIndex],
                      widget.withMonth ? _monthIndex + 1 : null,
                    )),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('确定', style: AppTextStyles.cn(14, color: confirmColor)),
                    ),
                  ),
                ],
              ),
            ),
            // 滚轮 (picker-view 高 420rpx, 行高 88rpx)
            SizedBox(
              height: 210,
              child: Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      items: [for (final y in widget.yearOptions) '$y年'],
                      initialIndex: widget.initialYearIndex,
                      isDark: isDark,
                      onChanged: (i) => _yearIndex = i,
                    ),
                  ),
                  if (widget.withMonth)
                    Expanded(
                      child: _Wheel(
                        items: [for (var m = 1; m <= 12; m++) '$m月'],
                        initialIndex: widget.initialMonthIndex,
                        isDark: isDark,
                        onChanged: (i) => _monthIndex = i,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final List<String> items;
  final int initialIndex;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _Wheel({required this.items, required this.initialIndex, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      itemExtent: 44, // 88rpx
      scrollController: FixedExtentScrollController(initialItem: initialIndex),
      onSelectedItemChanged: onChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F3F7), width: 0.5),
            bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F3F7), width: 0.5),
          ),
        ),
      ),
      children: [
        for (final item in items)
          Center(
            child: Text(
              item,
              style: AppTextStyles.num(15, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF2F3547)),
            ),
          ),
      ],
    );
  }
}
