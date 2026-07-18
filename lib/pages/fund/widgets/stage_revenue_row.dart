import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 阶段收益行数据（对应源码 stageGainList 项）
class StageGainRow {
  final String date;   // 周期
  final String fund;   // 本基金
  final String hs300;  // 沪深300
  final String excess; // 超额收益

  /// true=涨(is-rise) / false=跌(is-fall) / null=无数据(默认色)
  final bool? fundUp;
  final bool? hs300Up;
  final bool? excessUp;

  const StageGainRow({
    required this.date,
    required this.fund,
    required this.hs300,
    required this.excess,
    this.fundUp,
    this.hs300Up,
    this.excessUp,
  });
}

/// 阶段收益表头 — 1:1 复刻 stage-revenue.vue 的 .history-table-head
/// 网格 .85fr 1fr 1fr .85fr：周期(左) / 本基金(中) / 沪深300(中) / 超额收益(右)
/// padding 20rpx 6rpx 12rpx，22rpx=11 #a6a6a6
class StageRevenueTableHeader extends StatelessWidget {
  final bool isDark;

  const StageRevenueTableHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.cn(
      11, // 22rpx
      color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA6A6A6),
      height: 1.4,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 10, 3, 6), // 20rpx 6rpx 12rpx
      child: Row(
        children: [
          Expanded(flex: 85, child: Text('周期', style: style)),
          Expanded(flex: 100, child: Text('本基金', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 100, child: Text('沪深300', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 85, child: Text('超额收益', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// 阶段收益行 — 1:1 复刻 stage-revenue.vue 的 .history-row（numFamily 数字字体）
/// padding 22rpx 6rpx，border-top 1rpx #f0f0f0（深 #2B2D33），26rpx=13
class StageRevenueRow extends StatelessWidget {
  final StageGainRow row;
  final bool isDark;

  const StageRevenueRow({super.key, required this.row, required this.isDark});

  /// 源码 .is-rise 浅 #ff6b6b 深 #E05665 / .is-fall 浅 #15b887 深 #10B4A1
  Color _toneColor(bool? up, Color base) {
    if (up == null) return base;
    if (up) return isDark ? const Color(0xFFE05665) : const Color(0xFFFF6B6B);
    return isDark ? const Color(0xFF10B4A1) : const Color(0xFF15B887);
  }

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF242424);
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F0F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11), // 22rpx 6rpx
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider, width: 0.5)), // 1rpx
      ),
      child: Row(
        children: [
          Expanded(
            flex: 85,
            child: Text(row.date, style: AppTextStyles.num(13, color: base)),
          ),
          Expanded(
            flex: 100,
            child: Text(
              row.fund,
              textAlign: TextAlign.center,
              style: AppTextStyles.num(13, color: _toneColor(row.fundUp, base)),
            ),
          ),
          Expanded(
            flex: 100,
            child: Text(
              row.hs300,
              textAlign: TextAlign.center,
              style: AppTextStyles.num(13, color: _toneColor(row.hs300Up, base)),
            ),
          ),
          Expanded(
            flex: 85,
            child: Text(
              row.excess,
              textAlign: TextAlign.right,
              style: AppTextStyles.num(13, color: _toneColor(row.excessUp, base)),
            ),
          ),
        ],
      ),
    );
  }
}
