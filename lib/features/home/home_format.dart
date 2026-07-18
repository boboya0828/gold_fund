/// 首页数字格式化工具 — 1:1 复刻 uni-app utils/index.js keepTwoDecimalWithoutRound
/// 及 pages/index/index.vue 的 formatDecimal / formatSignedAmount / formatSignedPercent /
/// getPriceDigits / getProfitNumber。
library;

/// toNumber: 任意值转 double, 失败返回 null
double? homeToNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// keepTwoDecimalWithoutRound: 截断(不四舍五入)保留 digits 位, 输出定宽小数字符串
String _truncFixed(double value, int digits) {
  final sign = value < 0 ? -1 : 1;
  var factor = 1.0;
  for (var i = 0; i < digits; i++) {
    factor *= 10;
  }
  final abs = value.abs();
  // 对齐 JS: Math.floor(abs * factor + Number.EPSILON * factor) / factor
  final truncated = (abs * factor + 1e-9).floor() / factor;
  return (sign * truncated).toStringAsFixed(digits);
}

/// formatDecimal(value, digits, fallback): null → fallback, 否则截断 digits 位
String homeFmtDecimal(num? value, int digits, [String fallback = '0.00']) {
  if (value == null) return fallback;
  return _truncFixed(value.toDouble(), digits);
}

/// formatSignedAmount: >0 '+', <0 '-', ==0 无符号; 对绝对值截断
String homeFmtSignedAmount(num? value, [int digits = 2]) {
  if (value == null) return '+0.00';
  final v = value.toDouble();
  final prefix = v > 0 ? '+' : (v < 0 ? '-' : '');
  return '$prefix${_truncFixed(v.abs(), digits)}';
}

/// formatSignedPercent
String homeFmtSignedPercent(num? value, [int digits = 2]) =>
    '${homeFmtSignedAmount(value, digits)}%';

/// getPriceDigits: 价格 <100 保留 3 位, 其他保留 2 位
int homePriceDigits(num? price) {
  final v = homeToNum(price);
  return (v != null && v < 100) ? 3 : 2;
}

/// getProfitNumber: 去掉 '+', ',', '%' 后 parse, 失败返回 null
double? homeParseProfit(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(RegExp(r'[+,%]'), '');
  return double.tryParse(cleaned);
}
