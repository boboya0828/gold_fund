import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 行情详情折线图 — 1:1 复刻 zdj-v1 pages/market/details.vue 的 ECharts 配置
///
/// 两种模式（对应 .detailsinfo-tab 的 实时/业绩）：
/// - 分时(realtime)：固定 243 分钟交易轴(09:30-11:30 / 13:00-15:00)，X 轴只画
///   09:30、11:30/13:00、15:00 三个标签；无网格线；底部轴线 #F4F1EC；
///   线色随涨跌 红#F5465C / 绿#20B083，面积渐变 14% → 5% → 透明。
/// - 业绩(performance)：日 K 累计涨幅，X 轴只画首/中/尾日期；4 等分横向网格线
///   （去掉上下边界两条），线色固定 #F5465C，面积渐变 28% → 10% → 透明。
///
/// 触摸（按下/滑动）显示橙色竖线(#FFAA00 宽1)并把命中索引回调给父级，
/// 由父级渲染顶部自定义 tooltip 条（源码 tooltip triggerOn:'none' + 手动 showTip）；
/// 松开(FlPanEnd/FlTapUp/FlLongPressEnd 等)回调 null 隐藏。
class MarketDetailsChart extends StatelessWidget {
  final bool isDark;

  /// true=实时分时, false=业绩日K
  final bool isRealtime;

  /// 仅 realtime 用：涨跌方向（决定线/面积颜色）
  final bool isRise;

  /// realtime 数据：长度 243，null 表示该分钟无数据（connectNulls 跳过）
  final List<double?> realtimeValues;

  /// performance 数据：逐日累计涨幅(%)
  final List<double> perfValues;

  /// performance X 轴标签（与 perfValues 等长，仅首/中/尾非空）
  final List<String> perfLabels;

  /// 触摸命中数据点索引（realtime 为分钟轴索引，performance 为日索引）；null=松开
  final ValueChanged<int?> onTouchSpot;

  const MarketDetailsChart({
    super.key,
    required this.isDark,
    required this.isRealtime,
    required this.isRise,
    required this.realtimeValues,
    required this.perfValues,
    required this.perfLabels,
    required this.onTouchSpot,
  });

  // 源码 seriesColors[0]
  static const _riseColor = Color(0xFFF5465C);
  static const _fallColor = Color(0xFF20B083);

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    if (spots.isEmpty) return const SizedBox.expand();

    final isPerf = !isRealtime;
    final yRange = isPerf ? _perfYRange() : _realtimeYRange();
    final lineColor = isPerf
        ? _riseColor
        : (isRise ? _riseColor : _fallColor);
    final maxX = isPerf ? (perfValues.length - 1).toDouble() : 241.0; // 分钟轴 0..241

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: yRange.$1,
        maxY: yRange.$2,
        clipData: const FlClipData.all(),
        gridData: isPerf ? _perfGrid(yRange) : FlGridData(show: false),
        borderData: isPerf
            ? FlBorderData(show: false)
            // 分时模式 xAxis.axisLine: #f4f1ec 宽1 onZero:false（明暗同色，源码未做暗色覆盖）
            : FlBorderData(
                show: true,
                border: const Border(bottom: BorderSide(color: Color(0xFFF4F1EC), width: 1)),
              ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: isPerf ? _perfTitle : _realtimeTitle,
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          // 松开手指 → 隐藏竖线+tooltip（源码 onPointerUp: hideTip + updateAxisPointer leave）
          touchCallback: (event, response) {
            if (event is FlPanEndEvent ||
                event is FlPanCancelEvent ||
                event is FlTapUpEvent ||
                event is FlTapCancelEvent ||
                event is FlLongPressEnd ||
                event is FlPointerExitEvent) {
              onTouchSpot(null);
              return;
            }
            final spotsTouched = response?.lineBarSpots;
            if (spotsTouched == null || spotsTouched.isEmpty) {
              onTouchSpot(null);
              return;
            }
            // 用 FlSpot.x（时间轴原始索引），spotIndex 是过滤 null 后的数组下标，不可用
            onTouchSpot(spotsTouched.first.x.round());
          },
          // axisPointer: 橙色实线竖线，全高（默认 getTouchLineEnd 只画到命中点，需覆盖）
          getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
              .map((_) => const TouchedSpotIndicatorData(
                    FlLine(color: Color(0xFFFFAA00), strokeWidth: 1),
                    FlDotData(show: false),
                  ))
              .toList(),
          getTouchLineEnd: (_, _) => double.infinity,
          // 源码 tooltip formatter 返回空串，实际展示靠顶部自定义条 → 内置气泡全透明
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItems: (touchedSpots) => touchedSpots.map((_) => null).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false, // smooth: false
            barWidth: 1.5,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              // areaStyle origin:'start' → 填充到图表底部（fl_chart 默认行为）
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _areaColors(isPerf, isRise),
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
      duration: Duration.zero, // animation: false
    );
  }

  /// 构建折线点；null 值直接跳过（echarts connectNulls:true 的等价行为）
  List<FlSpot> _buildSpots() {
    if (isRealtime) {
      final spots = <FlSpot>[];
      for (var i = 0; i < realtimeValues.length; i++) {
        final v = realtimeValues[i];
        if (v != null) spots.add(FlSpot(i.toDouble(), v));
      }
      return spots;
    }
    return [
      for (var i = 0; i < perfValues.length; i++) FlSpot(i.toDouble(), perfValues[i]),
    ];
  }

  /// 分时 Y 轴范围：min - range*0.2 / max + range*0.1（空数据默认 -1..1）
  (double, double) _realtimeYRange() {
    final vals = realtimeValues.whereType<double>();
    if (vals.isEmpty) return (-1, 1);
    var min = double.infinity, max = -double.infinity;
    for (final v in vals) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = (max - min) == 0 ? 1.0 : (max - min);
    return (min - range * 0.2, max + range * 0.1);
  }

  /// 业绩 Y 轴范围：padding = max(range*0.18, 1)
  (double, double) _perfYRange() {
    var min = double.infinity, max = -double.infinity;
    for (final v in perfValues) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = (max - min) == 0 ? 1.0 : (max - min);
    final padding = range * 0.18 > 1 ? range * 0.18 : 1.0;
    return (min - padding, max + padding);
  }

  /// 业绩网格线：interval=(max-min)/4 共5条，去掉上下边界2条（源码 splitLine interval 回调）
  FlGridData _perfGrid((double, double) yRange) {
    final (yMin, yMax) = yRange;
    final interval = (yMax - yMin) / 4;
    const eps = 1e-9;
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (value) {
        if ((value - yMin).abs() < eps || (value - yMax).abs() < eps) {
          return const FlLine(color: Colors.transparent, strokeWidth: 0);
        }
        return FlLine(
          color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEF1F7),
          strokeWidth: 1,
        );
      },
    );
  }

  /// 分时 X 轴标签：FIXED_TIME_LABELS {09:30→0, 11:30→120(显示 11:30/13:00), 15:00→241}
  /// （分钟轴 09:30-11:30 共 121 点 + 13:00-15:00 共 121 点 = 242 点，索引 0..241）
  Widget _realtimeTitle(double value, TitleMeta meta) {
    final idx = value.round();
    final text = switch (idx) {
      0 => '09:30',
      120 => '11:30/13:00',
      241 => '15:00',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return _title(text, meta);
  }

  /// 业绩 X 轴标签：首/中/尾日期（labels 数组中仅有这三个非空）
  Widget _perfTitle(double value, TitleMeta meta) {
    final idx = value.round();
    if (idx < 0 || idx >= perfLabels.length) return const SizedBox.shrink();
    final text = perfLabels[idx];
    if (text.isEmpty) return const SizedBox.shrink();
    return _title(text, meta);
  }

  /// fitInside：把首/末标签内收到轴边界（echarts alignMinLabel:'left' / alignMaxLabel:'right'）
  Widget _title(String text, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 4,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
      child: Text(
        text,
        style: AppTextStyles.num(
          11,
          color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0B5BE),
        ),
      ),
    );
  }

  /// 面积渐变（chartGradient computed / 业绩模式渐变，1:1 色值与 stop）
  List<Color> _areaColors(bool isPerf, bool isRise) {
    final end = isDark ? const Color(0x00111315) : const Color(0x00FFFFFF);
    if (isPerf) {
      return [
        const Color(0x47E85F6F), // rgba(232,95,111,.28)
        const Color(0x1AE85F6F), // rgba(232,95,111,.10)
        isDark ? const Color(0x00111315) : const Color(0x00E85F6F),
      ];
    }
    if (isRise) {
      return [const Color(0x24E85F6F), const Color(0x0DE85F6F), end]; // .14/.05
    }
    return [const Color(0x2420B083), const Color(0x0D20B083), end];
  }
}
