/// 收益相关模型

/// 收益日历日数据
class ProfitDay {
  final DateTime date;
  final double profit;
  final double profitRate;
  final double? totalAssets;
  final List<ProfitDayDetail>? details;

  const ProfitDay({
    required this.date,
    required this.profit,
    required this.profitRate,
    this.totalAssets,
    this.details,
  });

  factory ProfitDay.fromJson(Map<String, dynamic> json) {
    return ProfitDay(
      date: DateTime.parse(json['date'] as String),
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      profitRate: (json['profitRate'] as num?)?.toDouble() ?? 0,
      totalAssets: (json['totalAssets'] as num?)?.toDouble(),
      details: (json['details'] as List?)
          ?.map((e) => ProfitDayDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isProfit => profit >= 0;
}

/// 收益日明细
class ProfitDayDetail {
  final int symbolId;
  final String? symbolCode;
  final String? symbolName;
  final int assetType;
  final double profit;
  final double profitRate;

  const ProfitDayDetail({
    required this.symbolId,
    this.symbolCode,
    this.symbolName,
    required this.assetType,
    required this.profit,
    required this.profitRate,
  });

  factory ProfitDayDetail.fromJson(Map<String, dynamic> json) {
    return ProfitDayDetail(
      symbolId: json['symbolId'] as int? ?? 0,
      symbolCode: json['symbolCode'] as String?,
      symbolName: json['symbolName'] as String?,
      assetType: json['assetType'] as int? ?? 12,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      profitRate: (json['profitRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 资产分布
class ProfitDistribution {
  final int symbolId;
  final String? symbolCode;
  final String? symbolName;
  final int assetType;
  final double marketValue;
  final double ratio; // 占比
  final double profit;
  final double profitRate;

  const ProfitDistribution({
    required this.symbolId,
    this.symbolCode,
    this.symbolName,
    required this.assetType,
    required this.marketValue,
    required this.ratio,
    required this.profit,
    required this.profitRate,
  });

  factory ProfitDistribution.fromJson(Map<String, dynamic> json) {
    return ProfitDistribution(
      symbolId: json['symbolId'] as int? ?? 0,
      symbolCode: json['symbolCode'] as String?,
      symbolName: json['symbolName'] as String?,
      assetType: json['assetType'] as int? ?? 12,
      marketValue: (json['marketValue'] as num?)?.toDouble() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      profitRate: (json['profitRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 账本收益摘要
class BookProfit {
  final int bookId;
  final String bookName;
  final double totalAssets;
  final double dayProfit;
  final double dayProfitRate;
  final double totalProfit;
  final double totalProfitRate;

  const BookProfit({
    required this.bookId,
    required this.bookName,
    required this.totalAssets,
    required this.dayProfit,
    required this.dayProfitRate,
    required this.totalProfit,
    required this.totalProfitRate,
  });

  factory BookProfit.fromJson(Map<String, dynamic> json) {
    return BookProfit(
      bookId: json['bookId'] as int? ?? 0,
      bookName: json['bookName'] as String? ?? '',
      totalAssets: (json['totalAssets'] as num?)?.toDouble() ?? 0,
      dayProfit: (json['dayProfit'] as num?)?.toDouble() ?? 0,
      dayProfitRate: (json['dayProfitRate'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      totalProfitRate: (json['totalProfitRate'] as num?)?.toDouble() ?? 0,
    );
  }
}
