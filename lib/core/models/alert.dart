/// 提醒/预警模型
class AssetAlert {
  final int id;
  final int symbolId;
  final String? symbolCode;
  final String? symbolName;
  final double? upThreshold;
  final double? downThreshold;
  final double? targetPrice;
  final int notifyChannels; // 位标志组合
  final bool isEnabled;
  final String? remark;
  final DateTime? createTime;

  const AssetAlert({
    required this.id,
    required this.symbolId,
    this.symbolCode,
    this.symbolName,
    this.upThreshold,
    this.downThreshold,
    this.targetPrice,
    this.notifyChannels = 1, // 默认 App 推送
    this.isEnabled = true,
    this.remark,
    this.createTime,
  });

  factory AssetAlert.fromJson(Map<String, dynamic> json) {
    return AssetAlert(
      id: json['id'] as int? ?? 0,
      symbolId: json['symbolId'] as int? ?? 0,
      symbolCode: json['symbolCode'] as String?,
      symbolName: json['symbolName'] as String?,
      upThreshold: (json['upThreshold'] as num?)?.toDouble(),
      downThreshold: (json['downThreshold'] as num?)?.toDouble(),
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
      notifyChannels: json['notifyChannels'] as int? ?? 1,
      isEnabled: json['isEnabled'] as bool? ?? true,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbolId': symbolId,
    'upThreshold': upThreshold,
    'downThreshold': downThreshold,
    'targetPrice': targetPrice,
    'notifyChannels': notifyChannels,
    'isEnabled': isEnabled,
    'remark': remark,
  };
}
