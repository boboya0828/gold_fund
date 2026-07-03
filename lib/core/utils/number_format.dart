/// 数字格式化工具 - 匹配 uni-app utils/index.js 中的格式化函数

/// 保留两位小数，不四舍五入（截断）
String keepTwoDecimalWithoutRound(double value) {
  final str = value.toStringAsFixed(10); // 高精度截取
  final dotIndex = str.indexOf('.');
  if (dotIndex == -1) return '$value.00';
  if (dotIndex + 3 <= str.length) {
    return str.substring(0, dotIndex + 3);
  }
  return str;
}

/// 格式化金额显示
/// 大额显示万/亿单位，保留两位小数
String formatMoney(double value) {
  if (value.abs() >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(2);
}

/// 格式化带符号的金额
String formatSignedMoney(double value) {
  final sign = value >= 0 ? '+' : '';
  final formatted = formatMoney(value.abs());
  return '$sign$formatted';
}

/// 格式化涨跌幅
String formatChangeRate(double rate) {
  final sign = rate >= 0 ? '+' : '';
  return '$sign${rate.toStringAsFixed(2)}%';
}

/// 格式化涨跌额
String formatChange(double change) {
  final sign = change >= 0 ? '+' : '';
  return '$sign${change.toStringAsFixed(2)}';
}

/// 格式化百分比 (0-100)
String formatPercent(double value) {
  return '${value.toStringAsFixed(2)}%';
}
