import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'curve_calendar_card.dart' show CurveSectionTitle;

/// 持仓分布数据点
class CurvePieDatum {
  final String name;
  final String valueText; // '12.3'
  final double value;
  final Color color;

  const CurvePieDatum({required this.name, required this.valueText, required this.value, required this.color});
}

/// 持仓结构卡 — 1:1 复刻 uni-app curve.vue `.piebox`
/// 基金占比 / 板块占比 / 类型占比 三个环形图(ECharts pie radius 40%-75%) + 图例(前5)
class CurvePieCard extends StatelessWidget {
  final bool isDark;
  final List<CurvePieDatum> fundData;
  final List<CurvePieDatum> sectorData;
  final List<CurvePieDatum> typeData;

  /// type: 'fund' / 'sector' / 'type'
  final ValueChanged<String> onMore;

  const CurvePieCard({
    super.key,
    required this.isDark,
    required this.fundData,
    required this.sectorData,
    required this.typeData,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), // mr-4 ml-4 mt-4
      padding: const EdgeInsets.only(bottom: 15), // 30rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5), // 10rpx
      ),
      child: Column(
        children: [
          CurveSectionTitle(isDark: isDark, title: '持仓结构'),
          _PieBlock(isDark: isDark, title: '基金占比', data: fundData, centerXOffset: -3, onMore: () => onMore('fund')),
          _PieBlock(isDark: isDark, title: '板块占比', data: sectorData, centerXOffset: -15, onMore: () => onMore('sector')),
          _PieBlock(isDark: isDark, title: '类型占比', data: typeData, centerXOffset: -15, onMore: () => onMore('type')),
        ],
      ),
    );
  }
}

class _PieBlock extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<CurvePieDatum> data;
  final double centerXOffset; // ECharts center 48%/40% 相对 50% 的偏移
  final VoidCallback onMore;

  const _PieBlock({
    required this.isDark,
    required this.title,
    required this.data,
    required this.centerXOffset,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final legend = data.length > 5 ? data.sublist(0, 5) : data;
    return Container(
      height: 182, // 364rpx
      margin: const EdgeInsets.fromLTRB(15, 10, 15, 0), // 20rpx 30rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFFBF9F9),
        borderRadius: BorderRadius.circular(10), // 20rpx
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 15, left: 40), // 30rpx / 80rpx
            child: Text(title,
                style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF452008), weight: FontWeight.w700)),
          ),
          // echarts-pie: 高 280rpx, padding 4rpx 40rpx 0 4rpx
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 20, 0),
              child: Row(
                children: [
                  // 环形图 300rpx × 280rpx
                  SizedBox(
                    width: 150,
                    height: 140,
                    child: data.isEmpty
                        ? const SizedBox.shrink()
                        : Transform.translate(
                            offset: Offset(centerXOffset, 3), // center y 52%
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 28, // ECharts radius 40% of ~71px
                                startDegreeOffset: 270, // ECharts 默认从 12 点方向开始
                                borderData: FlBorderData(show: false),
                                pieTouchData: PieTouchData(enabled: false), // silent: true
                                sections: [
                                  for (final d in data)
                                    PieChartSectionData(
                                      value: d.value,
                                      color: d.color,
                                      radius: 25, // 外径 53(75%) - 内径 28(40%)
                                      showTitle: false,
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // 图例
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final d in legend)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5), // 10rpx 0
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6, // 12rpx
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 6), // 12rpx
                                        decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                                      ),
                                      SizedBox(
                                        width: 100, // 200rpx
                                        child: Text(
                                          d.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.cn(11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF44312A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${d.valueText}%',
                                  style: AppTextStyles.num(11, color: isDark ? AppColors.darkText : const Color(0xFF3B2B25), weight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        if (data.length > 5)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onMore,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4), // 8rpx
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('更多',
                                    style: AppTextStyles.cn(12, color: isDark ? AppColors.upColor : const Color(0xFFBF633A))),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
