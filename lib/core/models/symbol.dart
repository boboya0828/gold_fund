/// 标的/代码相关模型
class SymbolInfo {
  final int id;
  final String code;
  final String name;
  final String? pinyin;
  final int type;
  final String? typeName;
  final double? latestPrice;
  final double? preClose;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? amount;
  final double? change;
  final double? changeRate;
  final DateTime? updateTime;
  final int? symbolId;
  final int? assetType;
  final int? assetId;

  const SymbolInfo({
    required this.id,
    required this.code,
    required this.name,
    this.pinyin,
    required this.type,
    this.typeName,
    this.latestPrice,
    this.preClose,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.amount,
    this.change,
    this.changeRate,
    this.updateTime,
    this.symbolId,
    this.assetType,
    this.assetId,
  });

  factory SymbolInfo.fromJson(Map<String, dynamic> json) {
    return SymbolInfo(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pinyin: json['pinyin'] as String?,
      type: json['type'] as int? ?? 0,
      typeName: json['typeName'] as String?,
      latestPrice: (json['latestPrice'] as num?)?.toDouble(),
      preClose: (json['preClose'] as num?)?.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      changeRate: (json['changeRate'] as num?)?.toDouble(),
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      symbolId: json['symbolId'] as int?,
      assetType: json['assetType'] as int?,
      assetId: json['assetId'] as int?,
    );
  }

  /// 是否上涨
  bool get isUp => (changeRate ?? 0) >= 0;

  /// 涨跌幅格式化
  String get changeRateFormatted {
    final rate = changeRate ?? 0;
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(2)}%';
  }

  /// 涨跌额格式化
  String get changeFormatted {
    final c = change ?? 0;
    final sign = c >= 0 ? '+' : '';
    return '$sign${c.toStringAsFixed(2)}';
  }
}

/// 首页标的查询结果
class HomeSymbolResult {
  final List<SymbolInfo> topSymbols;
  final List<SymbolInfo> marketList;
  final SymbolInfo? fundGroup;

  const HomeSymbolResult({
    this.topSymbols = const [],
    this.marketList = const [],
    this.fundGroup,
  });

  factory HomeSymbolResult.fromJson(Map<String, dynamic> json) {
    return HomeSymbolResult(
      topSymbols: (json['topSymbols'] as List?)
          ?.map((e) => SymbolInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      marketList: (json['marketList'] as List?)
          ?.map((e) => SymbolInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      fundGroup: json['fundGroup'] != null
          ? SymbolInfo.fromJson(json['fundGroup'] as Map<String, dynamic>)
          : null,
    );
  }
}
