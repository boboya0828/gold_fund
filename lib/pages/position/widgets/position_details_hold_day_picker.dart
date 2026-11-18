import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 持有天数修改弹层 — 1:1 复刻 position-details.vue up-picker（年|月|日 三列）
/// 按当前 holdDay 反推首买日初始化；日列随年月联动；
/// 确认回调传出 (years, months, days) 供页面换算总天数提交
class PositionDetailsHoldDayPicker extends StatefulWidget {
  final int initialYears;
  final int initialMonths;
  final int initialDays;
  final bool isDark;
  final void Function(int years, int months, int days) onConfirm;

  const PositionDetailsHoldDayPicker({
    super.key,
    required this.initialYears,
    required this.initialMonths,
    required this.initialDays,
    required this.isDark,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required int holdDay,
    required bool isDark,
    required void Function(int years, int months, int days) onConfirm,
  }) {
    // 1:1 源码：按 holdDay 反推（360 天/年、30 天/月 口径拆分到三列）
    final years = holdDay ~/ 360;
    final months = (holdDay % 360) ~/ 30;
    final days = holdDay % 30;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PositionDetailsHoldDayPicker(
        initialYears: years.clamp(0, 59),
        initialMonths: months.clamp(0, 11),
        initialDays: days.clamp(0, 30),
        isDark: isDark,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PositionDetailsHoldDayPicker> createState() =>
      _PositionDetailsHoldDayPickerState();
}

class _PositionDetailsHoldDayPickerState
    extends State<PositionDetailsHoldDayPicker> {
  late int _year = widget.initialYears;
  late int _month = widget.initialMonths;
  late int _day = widget.initialDays;

  static final _years = List.generate(60, (i) => i);
  static final _months = List.generate(12, (i) => i);

  /// 日列随年月联动（源码 setColumnValues：按是否 2 月/闰年给 28/29/30/31）
  List<int> get _days {
    final month = _month; // 0=当年第 1 个月口径
    if (month == 1) {
      final leap = _year % 4 == 0 && (_year % 100 != 0 || _year % 400 == 0);
      return [for (var i = 0; i <= (leap ? 28 : 27); i++) i];
    }
    const thirty = [3, 5, 8, 10];
    final max = thirty.contains(month) ? 29 : 30;
    return [for (var i = 0; i <= max; i++) i];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF202125) : Colors.white;
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9AA0AB);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.sx)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // toolbar：取消 / 持有天数 / 确定
          SizedBox(
            height: 48.sx, // 96rpx
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('取消',
                    style: AppTextStyles.cn(14.sx, color: subColor)),
              ),
              Expanded(
                child: Center(
                  child: Text('持有天数',
                      style: AppTextStyles.cn(15.sx,
                          color: textColor, weight: FontWeight.w600)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onConfirm(_year, _month, _day);
                },
                child: Text('确定',
                    style: AppTextStyles.cn(14.sx,
                        color: const Color(0xFFE05665), weight: FontWeight.w600)),
              ),
            ]),
          ),
          // toolbar 下方信息区：40rpx/700/#E05665 天数 + 22rpx/#9AA0AB 提示
          Padding(
            padding: EdgeInsets.only(bottom: 6.sx),
            child: Column(children: [
              Text('$_year 年 $_month 月 $_day 天',
                  style: AppTextStyles.num(20.sx,
                      color: const Color(0xFFE05665), weight: FontWeight.w700)),
              SizedBox(height: 2.sx),
              Text('按年/月/日调整持有天数',
                  style: AppTextStyles.cn(11.sx, color: subColor)),
            ]),
          ),
          // 三列滚轮
          SizedBox(
            height: 160.sx,
            child: Row(children: [
              Expanded(
                child: _wheel(
                  items: _years.map((e) => '$e 年').toList(),
                  selected: _year,
                  onChanged: (i) => setState(() {
                    _year = i;
                    final maxDay = _days.length - 1;
                    if (_day > maxDay) _day = maxDay;
                  }),
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _wheel(
                  items: _months.map((e) => '$e 月').toList(),
                  selected: _month,
                  onChanged: (i) => setState(() {
                    _month = i;
                    final maxDay = _days.length - 1;
                    if (_day > maxDay) _day = maxDay;
                  }),
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _wheel(
                  items: _days.map((e) => '$e 天').toList(),
                  selected: _day,
                  onChanged: (i) => setState(() => _day = i),
                  textColor: textColor,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _wheel({
    required List<String> items,
    required int selected,
    required ValueChanged<int> onChanged,
    required Color textColor,
  }) {
    return CupertinoPicker(
      itemExtent: 32.sx,
      scrollController:
          FixedExtentScrollController(initialItem: selected.clamp(0, items.length - 1)),
      onSelectedItemChanged: onChanged,
      children: [
        for (final item in items)
          Center(
            child: Text(item, style: AppTextStyles.cn(14.sx, color: textColor)),
          ),
      ],
    );
  }
}
