import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 滚轮选择条目 — 对应 uni-app picker-view-column 中的 item
class RunningTabPickerItem {
  final String label;
  final String value;
  const RunningTabPickerItem(this.label, this.value);
}

/// 底部滚轮选择弹层 — 1:1 复刻 zdj-v1/pages/index/fund/running-tab.vue 的
/// time-popup（picker-view + 取消/标题/确认 头部）。
///
/// 尺寸换算：rpx / 2 = px
/// header:  height 88rpx=44, padding 0 24rpx=12, font 28rpx=14
/// picker:  时间弹窗 500rpx=250 / 定投弹窗 460rpx=230, item height 50px
/// 弹层:    radius 24rpx=12（仅顶部）
class RunningTabWheelPicker extends StatefulWidget {
  final String title;

  /// 时间弹窗为“确定”，定投/转换弹窗为“确认”
  final String confirmText;
  final List<int> initialIndexes;

  /// 根据当前选中下标返回各列条目（支持定投周期 → 第二列联动）
  final List<List<RunningTabPickerItem>> Function(List<int> selected) columnsBuilder;

  /// 滚轮滚动回调（column, index），用于页面侧同步 temp 下标
  final void Function(int column, int index)? onChanged;
  final double pickerHeight;

  const RunningTabWheelPicker({
    super.key,
    required this.title,
    required this.initialIndexes,
    required this.columnsBuilder,
    this.onChanged,
    this.confirmText = '确认',
    this.pickerHeight = 250,
  });

  /// 弹出底部滚轮选择器；确认返回各列下标，取消/点遮罩返回 null
  static Future<List<int>?> show(
    BuildContext context, {
    required String title,
    required List<int> initialIndexes,
    required List<List<RunningTabPickerItem>> Function(List<int> selected) columnsBuilder,
    void Function(int column, int index)? onChanged,
    String confirmText = '确认',
    double pickerHeight = 250,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RunningTabWheelPicker(
        title: title,
        confirmText: confirmText,
        initialIndexes: initialIndexes,
        columnsBuilder: columnsBuilder,
        onChanged: onChanged,
        pickerHeight: pickerHeight,
      ),
    );
  }

  @override
  State<RunningTabWheelPicker> createState() => _RunningTabWheelPickerState();
}

class _RunningTabWheelPickerState extends State<RunningTabWheelPicker> {
  late final List<int> _selected = List<int>.of(widget.initialIndexes);
  late final List<FixedExtentScrollController> _controllers = [
    for (final i in widget.initialIndexes) FixedExtentScrollController(initialItem: i),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF202125) : Colors.white;
    final columns = widget.columnsBuilder(_selected);

    // 联动列条目数变少时收敛下标（如 每月31号 → 每周）
    for (var col = 0; col < columns.length && col < _selected.length; col++) {
      final max = columns[col].length - 1;
      if (max >= 0 && _selected[col] > max) {
        final target = max;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selected[col] = target);
          if (_controllers[col].hasClients) {
            _controllers[col].jumpToItem(target);
          }
          widget.onChanged?.call(col, target);
        });
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部: 取消 / 标题 / 确认
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: isDark
                    ? const Border(bottom: BorderSide(color: Color(0xFF2B2D33), width: 1))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '取消',
                          style: AppTextStyles.num(14,
                              color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9B9B9B)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.num(14,
                          color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(List<int>.of(_selected)),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          widget.confirmText,
                          style: AppTextStyles.num(14,
                              color: isDark ? const Color(0xFFE05665) : const Color(0xFFF2A22B)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 滚轮区
            Container(
              height: widget.pickerHeight,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202125) : null,
                border: isDark
                    ? null
                    : const Border(top: BorderSide(color: Color(0xFFF3F3F3), width: 1)),
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      for (var col = 0; col < columns.length; col++)
                        Expanded(child: _buildWheel(col, columns[col], isDark)),
                    ],
                  ),
                  // 选中指示器（picker-view indicator-style: height 50px）
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: isDark
                              ? null
                              : const Border(
                                  top: BorderSide(color: Color(0xFFEFEFEF), width: 1),
                                  bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // 深色模式遮罩渐变（源码 timePickerMaskStyle）
                  if (isDark)
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF202125),
                              Color(0x00202125),
                              Color(0x00202125),
                              Color(0xFF202125),
                            ],
                            stops: [0.0, 0.42, 0.58, 1.0],
                          ),
                        ),
                        child: SizedBox.expand(),
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

  Widget _buildWheel(int col, List<RunningTabPickerItem> items, bool isDark) {
    final itemColor = isDark ? const Color(0xFF686E78) : const Color(0xFFC7C7C7);
    final activeColor = isDark ? Colors.white : const Color(0xFF333333);
    return ListWheelScrollView.useDelegate(
      controller: _controllers[col],
      itemExtent: 50,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() => _selected[col] = index);
        widget.onChanged?.call(col, index);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: items.length,
        builder: (context, index) {
          final active = index == _selected[col];
          return Center(
            child: Text(
              items[index].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(
                15,
                color: active ? activeColor : itemColor,
                weight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}
