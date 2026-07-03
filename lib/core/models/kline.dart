/// K 线数据模型
class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double? amount;

  const KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.amount,
  });

  factory KlineData.fromJson(List<dynamic> row) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(
        (row[0] is String) ? int.parse(row[0] as String) : (row[0] as int),
      ),
      open: (row[1] as num).toDouble(),
      high: (row[2] as num).toDouble(),
      low: (row[3] as num).toDouble(),
      close: (row[4] as num).toDouble(),
      volume: (row[5] as num).toDouble(),
      amount: row.length > 6 ? (row[6] as num?)?.toDouble() : null,
    );
  }

  bool get isUp => close >= open;
}

/// K 线查询参数
class KlineParams {
  final int symbolId;
  final String period; // '1m', '5m', '15m', '30m', '60m', '1d', '1w', '1M'
  final int? limit;
  final DateTime? from;
  final DateTime? to;

  const KlineParams({
    required this.symbolId,
    required this.period,
    this.limit,
    this.from,
    this.to,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'symbolId': symbolId,
      'period': period,
    };
    if (limit != null) params['limit'] = limit;
    if (from != null) params['from'] = from!.toIso8601String();
    if (to != null) params['to'] = to!.toIso8601String();
    return params;
  }
}

/// 日线数据
class DailyLine {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double preClose;
  final double change;
  final double changeRate;
  final double volume;

  const DailyLine({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.preClose,
    required this.change,
    required this.changeRate,
    required this.volume,
  });

  factory DailyLine.fromJson(Map<String, dynamic> json) {
    return DailyLine(
      date: DateTime.parse(json['date'] as String),
      open: (json['open'] as num?)?.toDouble() ?? 0,
      high: (json['high'] as num?)?.toDouble() ?? 0,
      low: (json['low'] as num?)?.toDouble() ?? 0,
      close: (json['close'] as num?)?.toDouble() ?? 0,
      preClose: (json['preClose'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get isUp => close >= preClose;
}
