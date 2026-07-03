/// 资产明细模型
class AssetInfo {
  final int id;
  final int bookId;
  final int symbolId;
  final String? symbolCode;
  final String? symbolName;
  final int assetType;
  final String? assetTypeName;
  final double holdAmount;
  final double costPrice;
  final double? currentPrice;
  final double? marketValue;
  final double? totalProfit;
  final double? totalProfitRate;
  final double? dayProfit;
  final double? dayProfitRate;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int sortOrder;

  const AssetInfo({
    required this.id,
    required this.bookId,
    required this.symbolId,
    this.symbolCode,
    this.symbolName,
    required this.assetType,
    this.assetTypeName,
    required this.holdAmount,
    required this.costPrice,
    this.currentPrice,
    this.marketValue,
    this.totalProfit,
    this.totalProfitRate,
    this.dayProfit,
    this.dayProfitRate,
    this.createTime,
    this.updateTime,
    this.sortOrder = 0,
  });

  factory AssetInfo.fromJson(Map<String, dynamic> json) {
    return AssetInfo(
      id: json['id'] as int? ?? 0,
      bookId: json['bookId'] as int? ?? 0,
      symbolId: json['symbolId'] as int? ?? 0,
      symbolCode: json['symbolCode'] as String?,
      symbolName: json['symbolName'] as String?,
      assetType: json['assetType'] as int? ?? 12,
      assetTypeName: json['assetTypeName'] as String?,
      holdAmount: (json['holdAmount'] as num?)?.toDouble() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      marketValue: (json['marketValue'] as num?)?.toDouble(),
      totalProfit: (json['totalProfit'] as num?)?.toDouble(),
      totalProfitRate: (json['totalProfitRate'] as num?)?.toDouble(),
      dayProfit: (json['dayProfit'] as num?)?.toDouble(),
      dayProfitRate: (json['dayProfitRate'] as num?)?.toDouble(),
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

/// 资产概览
class AssetOverview {
  final double totalAssets;
  final double totalProfit;
  final double totalProfitRate;
  final double dayProfit;
  final double dayProfitRate;
  final double? metalAssets;
  final double? metalProfit;
  final double? fundAssets;
  final double? fundProfit;

  const AssetOverview({
    required this.totalAssets,
    required this.totalProfit,
    required this.totalProfitRate,
    required this.dayProfit,
    required this.dayProfitRate,
    this.metalAssets,
    this.metalProfit,
    this.fundAssets,
    this.fundProfit,
  });

  factory AssetOverview.fromJson(Map<String, dynamic> json) {
    return AssetOverview(
      totalAssets: (json['totalAssets'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      totalProfitRate: (json['totalProfitRate'] as num?)?.toDouble() ?? 0,
      dayProfit: (json['dayProfit'] as num?)?.toDouble() ?? 0,
      dayProfitRate: (json['dayProfitRate'] as num?)?.toDouble() ?? 0,
      metalAssets: (json['metalAssets'] as num?)?.toDouble(),
      metalProfit: (json['metalProfit'] as num?)?.toDouble(),
      fundAssets: (json['fundAssets'] as num?)?.toDouble(),
      fundProfit: (json['fundProfit'] as num?)?.toDouble(),
    );
  }

  /// 是否盈利
  bool get isUp => totalProfitRate >= 0;
}
