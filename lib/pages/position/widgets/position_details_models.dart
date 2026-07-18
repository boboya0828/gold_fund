import 'package:flutter/material.dart';

/// 持仓详情页共享小模型 / 颜色 / 格式化工具
/// uni-app 对应: pages/index/fund/position-details.vue

// ===== 页面级涨跌色（position-details.vue .is-rise / .is-fall）=====
const kPdRiseColor = Color(0xFFF04D5D);
const kPdFallColor = Color(0xFF12A874);
// 图表用涨跌色（tooltip / 日历等）
const kPdChartRed = Color(0xFFF5465C);
const kPdChartGreen = Color(0xFF20B083);
// 关联涨跌多折线固定配色（seriesColors）
const kPdSeriesColors = <Color>[
  Color(0xFFF5465C),
  Color(0xFFFF7A45),
  Color(0xFF3478F6),
  Color(0xFF8E6FF7),
  Color(0xFF00B8D9),
  Color(0xFFFF9F43),
];

Color pdProfitColor(num? v) => ((v ?? 0) >= 0) ? kPdRiseColor : kPdFallColor;

/// 截断保留 digits 位小数（不四舍五入），1:1 uni-app $utils.keepTwoDecimalWithoutRound
String pdKeepDecimals(double value, int digits) {
  if (value.isNaN || value.isInfinite) return '--';
  final neg = value < 0;
  final str = value.abs().toStringAsFixed(10);
  final dot = str.indexOf('.');
  String out;
  if (digits <= 0) {
    out = str.substring(0, dot);
  } else if (dot + digits + 1 <= str.length) {
    out = str.substring(0, dot + digits + 1);
  } else {
    out = str;
  }
  return '${neg ? '-' : ''}$out';
}

/// formatDetailValue: 非有限数 → '--'
String pdFmt(dynamic v, [int digits = 2, String suffix = '']) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null || !n.isFinite) return '--';
  return '${pdKeepDecimals(n, digits)}$suffix';
}

/// formatSignedDetailValue: 正数带 '+' 前缀
String pdFmtSigned(dynamic v, [int digits = 2, String suffix = '']) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null || !n.isFinite) return '--';
  return '${n > 0 ? '+' : ''}${pdKeepDecimals(n, digits)}$suffix';
}

/// formatPercentText: `${num >= 0 ? '+' : ''}${num.toFixed(2)}%`
String pdFmtPercent(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null || !n.isFinite) return '--';
  return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}%';
}

double? pdNum(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  return (n == null || !n.isFinite) ? null : n;
}

/// 顶部 3 指标 / 持仓 9 指标共用的小项
class PdMetricItem {
  final String label;
  final String value;
  final Color? valueColor;
  const PdMetricItem(this.label, this.value, {this.valueColor});
}

/// 账本 tab
class PdBookTab {
  final int bookId;
  final String bookName;
  const PdBookTab(this.bookId, this.bookName);
}

/// 业绩走势数据点
class PdTrendPoint {
  final String tradeDate;
  final double value;
  final double close;
  final double percent;
  const PdTrendPoint({required this.tradeDate, required this.value, required this.close, required this.percent});
}

/// 关联涨跌单条折线
class PdSectorSeries {
  final String name;
  final Color color;
  final List<double?> values;
  final List<String> times;
  const PdSectorSeries({required this.name, required this.color, required this.values, this.times = const []});
}

/// 阶段/月度/季度 收益表行
class PdStageRow {
  final String date;
  final String change;
  final String hs300;
  final String excess;
  final double? changeRaw;
  final double? hs300Raw;
  final double? excessRaw;
  const PdStageRow({
    required this.date,
    required this.change,
    required this.hs300,
    required this.excess,
    this.changeRaw,
    this.hs300Raw,
    this.excessRaw,
  });
}

/// 历史净值行
class PdHistoryRow {
  final String date;
  final String unitValue;
  final String change;
  final double changeRaw;
  const PdHistoryRow({required this.date, required this.unitValue, required this.change, required this.changeRaw});
}

/// 弹幕条目
class PdDanmuItem {
  final String id;
  final String text;
  final String tone; // gray/red/green/blue/orange
  final int topIndex;
  final double durationSec;
  final double delaySec;
  final bool isOwn;
  const PdDanmuItem({
    required this.id,
    required this.text,
    required this.tone,
    required this.topIndex,
    required this.durationSec,
    this.delaySec = 0,
    this.isOwn = false,
  });
}

/// 收益日历单元格
class PdCalendarDay {
  final int? day;
  final String value;
  final String percentValue;
  final String type; // '' | 'rise' | 'loss'
  final String tag; // '休' | ''
  final bool isToday;
  const PdCalendarDay({
    this.day,
    this.value = '',
    this.percentValue = '',
    this.type = '',
    this.tag = '',
    this.isToday = false,
  });
}

/// 月/年视图格子
class PdCalendarCell {
  final int keyValue; // month(1-12) or year
  final String value;
  final bool isActive;
  const PdCalendarCell(this.keyValue, this.value, {this.isActive = false});
}

/// 底部动作项
class PdActionItem {
  final String label;
  final IconData? icon;
  final double iconSize;
  final String type; // 'icon' | 'button'
  final String accent; // '' | 'sell' | 'buy' | 'add'
  const PdActionItem({required this.label, this.icon, this.iconSize = 18, this.type = 'icon', this.accent = ''});
}
