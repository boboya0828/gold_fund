import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 日期选择弹层 — 1:1 复刻 uni-app pages/user/profit-detail.vue 的
/// uni-popup + picker-view（年/月/日三列，行高 70rpx，高 400rpx）
///
/// 注意：uni-app 源码中触发该弹层的日期栏已被注释（dead code），
/// 此组件为对齐弹层结构而保留，页面暂无可触发的入口。
class ProfitDetailDateSheet extends StatefulWidget {
  final bool isDark;
  final DateTime initialDate;

  const ProfitDetailDateSheet({
    super.key,
    required this.isDark,
    required this.initialDate,
  });

  /// 弹出日期选择器；确定返回 'yyyy-MM-dd'，取消返回 null
  static Future<String?> show(
    BuildContext context, {
    required bool isDark,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfitDetailDateSheet(
        isDark: isDark,
        initialDate: initialDate ?? DateTime.now(),
      ),
    );
  }

  @override
  State<ProfitDetailDateSheet> createState() => _ProfitDetailDateSheetState();
}

class _ProfitDetailDateSheetState extends State<ProfitDetailDateSheet> {
  // uni-app initPicker: years = 当前年-5 ~ 当前年（共6个）
  late final List<int> _years = [for (var i = 0; i < 6; i++) DateTime.now().year - 5 + i];
  static const _months = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  late int _yearIndex = _years.indexOf(widget.initialDate.year).clamp(0, _years.length - 1);
  late int _monthIndex = widget.initialDate.month - 1;
  late int _dayCount = _daysInMonth(_years[_yearIndex], _monthIndex + 1);
  late int _dayIndex = (widget.initialDate.day - 1).clamp(0, _dayCount - 1);

  late final FixedExtentScrollController _yearController =
      FixedExtentScrollController(initialItem: _yearIndex);
  late final FixedExtentScrollController _monthController =
      FixedExtentScrollController(initialItem: _monthIndex);
  late final FixedExtentScrollController _dayController =
      FixedExtentScrollController(initialItem: _dayIndex);

  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  /// uni-app onPickerChange / updateDays：年月变化时联动日数
  void _syncDays() {
    final dim = _daysInMonth(_years[_yearIndex], _monthIndex + 1);
    if (dim == _dayCount && _dayIndex < dim) return;
    setState(() {
      _dayCount = dim;
      if (_dayIndex >= dim) {
        _dayIndex = dim - 1;
        _dayController.jumpToItem(_dayIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF202125) : Colors.white;
    final wheelBg = isDark ? const Color(0xFF282828) : Colors.transparent;
    final cancelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF999999);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF333333);

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
            // 头部：取消 / 选择日期 / 确定
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), // 24rpx 30rpx
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF5F5F5),
                    width: 0.5, // 1rpx
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('取消', style: AppTextStyles.cn(14, color: cancelColor)),
                  ),
                  Text('选择日期', style: AppTextStyles.cn(15, color: titleColor, weight: FontWeight.w500)),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onConfirm,
                    child: Text('确定', style: AppTextStyles.cn(14, color: AppColors.upColor, weight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            // 滚轮区（picker-view 高 400rpx）
            Container(
              height: 200,
              color: wheelBg,
              child: Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      items: [for (final y in _years) '$y年'],
                      controller: _yearController,
                      selectedIndex: _yearIndex,
                      isDark: isDark,
                      onChanged: (i) {
                        setState(() => _yearIndex = i);
                        _syncDays();
                      },
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      items: [for (final m in _months) '$m月'],
                      controller: _monthController,
                      selectedIndex: _monthIndex,
                      isDark: isDark,
                      onChanged: (i) {
                        setState(() => _monthIndex = i);
                        _syncDays();
                      },
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      items: [for (var d = 1; d <= _dayCount; d++) '$d日'],
                      controller: _dayController,
                      selectedIndex: _dayIndex,
                      isDark: isDark,
                      onChanged: (i) => setState(() => _dayIndex = i),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // padding-bottom 40rpx
          ],
        ),
      ),
    );
  }

  /// uni-app confirmDate
  void _onConfirm() {
    final y = _years[_yearIndex];
    final m = (_monthIndex + 1).toString().padLeft(2, '0');
    final d = (_dayIndex + 1).toString().padLeft(2, '0');
    Navigator.of(context).pop('$y-$m-$d');
  }
}

class _Wheel extends StatelessWidget {
  final List<String> items;
  final FixedExtentScrollController controller;
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.items,
    required this.controller,
    required this.selectedIndex,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      itemExtent: 35, // 70rpx
      scrollController: controller,
      onSelectedItemChanged: onChanged,
      // 浅色：picker-view 默认指示器（上下边线）；深色：indicator-style border: 0
      selectionOverlay: isDark
          ? const SizedBox.shrink()
          : Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F3F7), width: 0.5),
                  bottom: BorderSide(color: Color(0xFFF1F3F7), width: 0.5),
                ),
              ),
            ),
      children: [
        for (var i = 0; i < items.length; i++)
          Center(
            child: Text(
              items[i],
              style: AppTextStyles.cn(
                15, // 30rpx
                color: isDark
                    ? (i == selectedIndex ? Colors.white : AppColors.darkTextSecondary)
                    : const Color(0xFF333333),
                weight: i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}
