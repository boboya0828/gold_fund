/// 交易记录模型
class TradeRecord {
  final int id;
  final int assetId;
  final int tradeType;
  final String? tradeTypeName;
  final double amount;
  final double price;
  final double? fee;
  final String? remark;
  final DateTime? tradeTime;
  final DateTime? createTime;

  const TradeRecord({
    required this.id,
    required this.assetId,
    required this.tradeType,
    this.tradeTypeName,
    required this.amount,
    required this.price,
    this.fee,
    this.remark,
    this.tradeTime,
    this.createTime,
  });

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    return TradeRecord(
      id: json['id'] as int? ?? 0,
      assetId: json['assetId'] as int? ?? 0,
      tradeType: json['tradeType'] as int? ?? 0,
      tradeTypeName: json['tradeTypeName'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      fee: (json['fee'] as num?)?.toDouble(),
      remark: json['remark'] as String?,
      tradeTime: json['tradeTime'] != null
          ? DateTime.tryParse(json['tradeTime'] as String)
          : null,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
    );
  }

  /// 交易金额 (amount * price)
  double get tradeValue => amount * price;
}

/// 交易统计
class TradeStats {
  final double totalBuyAmount;
  final double totalSellAmount;
  final double totalFee;
  final int tradeCount;

  const TradeStats({
    required this.totalBuyAmount,
    required this.totalSellAmount,
    required this.totalFee,
    required this.tradeCount,
  });

  factory TradeStats.fromJson(Map<String, dynamic> json) {
    return TradeStats(
      totalBuyAmount: (json['totalBuyAmount'] as num?)?.toDouble() ?? 0,
      totalSellAmount: (json['totalSellAmount'] as num?)?.toDouble() ?? 0,
      totalFee: (json['totalFee'] as num?)?.toDouble() ?? 0,
      tradeCount: json['tradeCount'] as int? ?? 0,
    );
  }
}
