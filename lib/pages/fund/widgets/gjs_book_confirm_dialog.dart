import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 贵金属记账确认弹窗行 — label + value（数值用 DIN 字体）
class GjsBookConfirmRow {
  final String label;
  final String value;

  /// 源码 confirm-popup__value 是否带 numFamily
  final bool numeric;
  const GjsBookConfirmRow(this.label, this.value, {this.numeric = true});
}

/// 贵金属买入/卖出确认弹窗 — 1:1 复刻 gjs-bookkeeping.vue 的 confirm-popup
///
/// 尺寸换算：rpx / 2 = px
/// 弹窗宽 620rpx=310, radius 16rpx=8
/// 标题 32rpx=16, 行 28rpx=14(label 宽 150rpx=75), 提示 22rpx=11, 底部 88rpx=44
/// 提示文案：此处为模拟交易，非真实交易 / 仅作为贵金属记账使用
class GjsBookConfirmDialog extends StatelessWidget {
  final String title;
  final List<GjsBookConfirmRow> rows;

  const GjsBookConfirmDialog({super.key, required this.title, required this.rows});

  /// 确认返回 true，取消/点遮罩返回 false
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required List<GjsBookConfirmRow> rows,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => GjsBookConfirmDialog(title: title, rows: rows),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF202125) : Colors.white;
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF555555);
    final valueColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF4A4A4A);
    final cancelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666);
    const accent = Color(0xFFE85F6F);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32.5),
      child: Container(
        width: 310,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 14), // 40rpx 0 28rpx
              child: Text(title, style: AppTextStyles.cn(16, color: titleColor)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36), // 72rpx
              child: Column(
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(top: 11), // 22rpx
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 75, // 150rpx
                            child: Text(row.label,
                                style: AppTextStyles.cn(14, color: labelColor, height: 1.4)),
                          ),
                          Expanded(
                            child: Text(
                              row.value,
                              style: row.numeric
                                  ? AppTextStyles.num(14, color: valueColor, height: 1.4)
                                  : AppTextStyles.cn(14, color: valueColor, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 26, bottom: 21), // 52rpx 0 42rpx
              child: Column(
                children: [
                  Text('此处为模拟交易，非真实交易',
                      style: AppTextStyles.cn(11, color: accent, height: 1.5)),
                  Text('仅作为贵金属记账使用',
                      style: AppTextStyles.cn(11, color: accent, height: 1.5)),
                ],
              ),
            ),
            Container(
              height: 44, // 88rpx
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFEF),
                      width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(false),
                      child: Center(
                          child: Text('取消', style: AppTextStyles.cn(13, color: cancelColor))),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(true),
                      child: Center(
                          child: Text('确认', style: AppTextStyles.cn(13, color: accent))),
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
