import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import 'position_details_danmu.dart';
import 'position_details_models.dart';

/// 持仓详情 — 图表卡 tab 栏（关联涨跌 / 业绩走势 / 我的收益）
/// uni-app 对应: position-details.vue 的 .chart-tabs
class PositionDetailsChartTabs extends StatelessWidget {
  final List<Map<String, String>> tabs;
  final String activeTab;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const PositionDetailsChartTabs({
    super.key,
    required this.tabs,
    required this.activeTab,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44, // 88rpx
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(t['value']!),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      t['label']!,
                      style: AppTextStyles.cn(13,
                          color: activeTab == t['value']
                              ? (isDark ? AppColors.darkText : const Color(0xFF222222))
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF666666)),
                          weight: activeTab == t['value'] ? FontWeight.w700 : FontWeight.w400),
                    ),
                    if (activeTab == t['value'])
                      Positioned(
                        bottom: 5, // 10rpx
                        child: Container(
                          width: 28, // 56rpx
                          height: 3, // 6rpx
                          decoration: BoxDecoration(
                            color: kPdChartRed,
                            borderRadius: BorderRadius.circular(999),
                          ),
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

/// 关联涨跌面板（分钟多折线 + 弹幕 + 看涨看跌）
/// uni-app 对应: .chart-grid (sector) + .danmu-layer + .discuss
class PositionDetailsSectorPanel extends StatelessWidget {
  final bool isDark;
  final List<PdSectorSeries> seriesList;
  final String tooltipTime;
  final String maxPct;
  final String minPct;

  // 弹幕
  final bool danmuOn;
  final int danmuRenderKey;
  final List<PdDanmuItem> danmuItems;
  final String riseText;
  final String fallText;
  final VoidCallback onToggleDanmu;
  final VoidCallback onOpenDanmuPanel;
  final ValueChanged<String> onVote; // 'rise' | 'fall'
  final ValueChanged<PdDanmuItem> onReportDanmu;

  const PositionDetailsSectorPanel({
    super.key,
    required this.isDark,
    required this.seriesList,
    required this.tooltipTime,
    required this.maxPct,
    required this.minPct,
    required this.danmuOn,
    required this.danmuRenderKey,
    required this.danmuItems,
    required this.riseText,
    required this.fallText,
    required this.onToggleDanmu,
    required this.onOpenDanmuPanel,
    required this.onVote,
    required this.onReportDanmu,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8A8F9B);
    final allValues = [for (final s in seriesList) ...s.values.whereType<double>()];
    final hasData = allValues.isNotEmpty;
    final rawMin = hasData ? allValues.reduce((a, b) => a < b ? a : b) : -1.0;
    final rawMax = hasData ? allValues.reduce((a, b) => a > b ? a : b) : 1.0;
    final range = (rawMax - rawMin).abs() < 1e-9 ? 1.0 : rawMax - rawMin;
    final minY = rawMin - (range * 0.2 > 0.3 ? range * 0.2 : 0.3);
    final maxY = rawMax + (range * 0.1 > 0.3 ? range * 0.1 : 0.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 12), // 18rpx 20rpx 24rpx
      child: Column(
        children: [
          // tooltip 行：日期 + 各系列最新值
          Row(
            children: [
              Text('日期: $tooltipTime', style: AppTextStyles.cn(10, color: labelColor)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < seriesList.length; i++)
                      _seriesChip(seriesList[i]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // 20rpx
          SizedBox(
            height: 200, // 400rpx
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text(maxPct, style: AppTextStyles.num(11, color: labelColor)),
                ),
                Positioned(
                  left: 0,
                  bottom: 20,
                  child: Text(minPct, style: AppTextStyles.num(11, color: labelColor)),
                ),
                Positioned.fill(
                  child: hasData
                      ? LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              for (final s in seriesList)
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < s.values.length; i++)
                                      if (s.values[i] != null) FlSpot(i.toDouble(), s.values[i]!),
                                  ],
                                  isCurved: false,
                                  color: s.color,
                                  barWidth: 1.4,
                                  dotData: const FlDotData(show: false),
                                ),
                            ],
                          ),
                        )
                      : Center(child: Text('暂无数据', style: AppTextStyles.cn(12, color: labelColor))),
                ),
                // 弹幕层
                if (danmuOn)
                  Positioned.fill(
                    child: PositionDetailsDanmuLayer(
                      items: danmuItems,
                      isDark: isDark,
                      renderKey: danmuRenderKey,
                      onReport: onReportDanmu,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8), // 16rpx
          // 讨论条：弹幕开关 + 发弹幕 + 看涨/看跌
          SizedBox(
            height: 27, // 54rpx
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggleDanmu,
                  child: SizedBox(
                    width: 27,
                    height: 27,
                    child: Icon(danmuOn ? AppIcons.danmakuOn : AppIcons.danmakuOff,
                        size: 20, color: isDark ? AppColors.darkText : const Color(0xFF555555)),
                  ),
                ),
                const SizedBox(width: 9), // 18rpx
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenDanmuPanel,
                    child: Container(
                      height: 27,
                      padding: const EdgeInsets.symmetric(horizontal: 11), // 22rpx
                      alignment: Alignment.centerLeft,
                      color: isDark ? const Color(0xFF282828) : const Color(0xFFFAFAFA),
                      child: Text('点我发弹幕',
                          style: AppTextStyles.cn(11,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB8B8BD), weight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                _voteButton(riseText, true, () => onVote('rise')),
                Transform.translate(offset: const Offset(-4, 0), child: _voteButton(fallText, false, () => onVote('fall'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seriesChip(PdSectorSeries s) {
    final lastVal = s.values.lastWhere((v) => v != null, orElse: () => null);
    final valText = lastVal == null ? '--' : '${lastVal >= 0 ? '+' : ''}${lastVal.toStringAsFixed(2)}%';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text(s.name, style: AppTextStyles.cn(10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8A8F9B))),
      const SizedBox(width: 3),
      Text(valText,
          style: AppTextStyles.num(10, color: (lastVal ?? 0) >= 0 ? kPdChartRed : kPdChartGreen)),
    ]);
  }

  Widget _voteButton(String text, bool isRise, VoidCallback onTap) {
    // uni-app 用 skewX(-14deg) 平行四边形按钮
    final bg = isRise
        ? (isDark ? const Color(0xFF322329) : const Color(0xFFFDEDEE))
        : (isDark ? const Color(0xFF22302E) : const Color(0xFFDDF2EA));
    final color = isRise ? const Color(0xFFFF6562) : const Color(0xFF16AF8A);
    return GestureDetector(
      onTap: onTap,
      child: Transform(
        transform: Matrix4.skewX(-0.24),
        alignment: Alignment.center,
        child: Container(
          width: 75, // 150rpx
          height: 27, // 54rpx
          color: bg,
          alignment: Alignment.center,
          child: Transform(
            transform: Matrix4.skewX(0.24),
            alignment: Alignment.center,
            child: Text(text, style: AppTextStyles.cn(11, color: color, weight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

/// 业绩走势面板（区间收益折线 + 区间切换）
/// uni-app 对应: .trend-panel
class PositionDetailsTrendPanel extends StatelessWidget {
  final bool isDark;
  final List<PdTrendPoint> points;
  final int hoveredIndex;
  final ValueChanged<int> onHover;
  final List<Map<String, Object>> rangeTabs; // [{label, value, days}]
  final String activeRange;
  final ValueChanged<String> onRangeChange;
  final bool loading;

  const PositionDetailsTrendPanel({
    super.key,
    required this.isDark,
    required this.points,
    required this.hoveredIndex,
    required this.onHover,
    required this.rangeTabs,
    required this.activeRange,
    required this.onRangeChange,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final axisColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFB0B5BE);
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8A8F9B);
    final textColor = isDark ? AppColors.darkText : const Color(0xFF30364A);

    final idx = (hoveredIndex >= 0 && hoveredIndex < points.length)
        ? hoveredIndex
        : (points.isNotEmpty ? points.length - 1 : -1);
    final legendDate = idx >= 0 ? points[idx].tradeDate : '--';
    final legendClose = idx >= 0 ? points[idx].close : 0.0;
    final legendVal = idx >= 0 ? points[idx].percent : 0.0;
    final legendText = '${legendVal >= 0 ? '+' : ''}${legendVal.toStringAsFixed(2)}%';

    final percents = [for (final p in points) p.percent];
    final maxV = percents.isNotEmpty ? percents.reduce((a, b) => a > b ? a : b) : 0.0;
    final minV = percents.isNotEmpty ? percents.reduce((a, b) => a < b ? a : b) : 0.0;
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final pad = range * 0.18 > 1 ? range * 0.18 : 1.0;
    final mid = points.isNotEmpty ? (points.length - 1) ~/ 2 : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 12),
      child: Column(
        children: [
          // 图例行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(legendDate, style: AppTextStyles.num(12, color: textColor)),
                const SizedBox(width: 5),
                Text(pdKeepDecimals(legendClose, 3), style: AppTextStyles.num(12, color: textColor)),
              ]),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: kPdChartRed, shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text('本基金', style: AppTextStyles.cn(11, color: labelColor)),
                const SizedBox(width: 4),
                Text(legendText, style: AppTextStyles.num(12, color: legendVal >= 0 ? kPdRiseColor : kPdFallColor)),
              ]),
            ],
          ),
          const SizedBox(height: 7), // 14rpx
          SizedBox(
            height: 215, // 430rpx
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 10,
                  child: Text('${maxV >= 0 ? '+' : ''}${maxV.toStringAsFixed(2)}%',
                      style: AppTextStyles.num(11, color: labelColor)),
                ),
                Positioned(
                  left: 0,
                  bottom: 31,
                  child: Text('${minV >= 0 ? '+' : ''}${minV.toStringAsFixed(2)}%',
                      style: AppTextStyles.num(11, color: labelColor)),
                ),
                Positioned.fill(
                  child: points.isEmpty
                      ? Center(
                          child: Text(loading ? '加载中...' : '暂无数据', style: AppTextStyles.cn(12, color: labelColor)),
                        )
                      : LineChart(
                          LineChartData(
                            minY: minV - pad,
                            maxY: maxV + pad,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 18,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (value != i.toDouble()) return const SizedBox.shrink();
                                    if (i != 0 && i != mid && i != points.length - 1) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 5), // 10rpx margin
                                      child: Text(points[i].tradeDate, style: AppTextStyles.num(11, color: axisColor)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((_) => null).toList()),
                              getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                                  .map((i) => TouchedSpotIndicatorData(
                                        FlLine(color: axisColor, strokeWidth: 1, dashArray: const [4, 4]),
                                        const FlDotData(show: true),
                                      ))
                                  .toList(),
                              touchCallback: (event, response) {
                                final spots = response?.lineBarSpots;
                                if (spots != null && spots.isNotEmpty) onHover(spots.first.spotIndex);
                              },
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].percent)],
                                isCurved: false,
                                color: kPdChartRed,
                                barWidth: 1.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [kPdChartRed.withValues(alpha: 0.16), kPdChartRed.withValues(alpha: 0.0)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          // 区间切换
          Padding(
            padding: const EdgeInsets.only(top: 9), // 18rpx
            child: Row(
              children: [
                for (final t in rangeTabs)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onRangeChange(t['value'] as String),
                      child: Container(
                        height: 28, // 56rpx
                        margin: const EdgeInsets.symmetric(horizontal: 4), // 8rpx gap
                        decoration: BoxDecoration(
                          color: activeRange == t['value'] ? AppColors.upColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(25), // 50rpx
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          t['label'] as String,
                          style: AppTextStyles.cn(11,
                              color: activeRange == t['value']
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF666666))),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
