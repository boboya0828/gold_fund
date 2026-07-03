/// 枚举定义 - 匹配 uni-app api/api.js 中的枚举类型

/// 资产类型 (1-12)
enum AssetType {
  gold(1, '黄金'),
  silver(2, '白银'),
  fund(3, '基金'),
  stock(4, '股票'),
  bond(5, '债券'),
  deposit(6, '定期理财'),
  futures(7, '期货'),
  option(8, '期权'),
  forex(9, '外汇'),
  realEstate(10, '不动产'),
  insurance(11, '保险'),
  other(12, '其他');

  final int value;
  final String label;
  const AssetType(this.value, this.label);

  static AssetType fromValue(int value) {
    return AssetType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssetType.other,
    );
  }
}

/// 交易类型
enum AssetTradeType {
  buy(0, '买入'),
  sell(1, '卖出'),
  bonus(2, '分红'),
  split(3, '拆分');

  final int value;
  final String label;
  const AssetTradeType(this.value, this.label);
}

/// 账本分类
enum BookCategory {
  general(0, '通用'),
  position(1, '持仓'),
  favorite(2, '自选');

  final int value;
  final String label;
  const BookCategory(this.value, this.label);
}

/// 通知渠道 (位标志)
enum NotifyChannel {
  app(1, 'App推送'),
  wechat(2, '微信'),
  sms(4, '短信'),
  email(8, '邮件');

  final int bit;
  final String label;
  const NotifyChannel(this.bit, this.label);
}

/// 价格类型
enum PriceType {
  current(0, '现价'),
  cost(1, '成本价'),
  preClose(2, '昨收'),
  open(3, '开盘');

  final int value;
  final String label;
  const PriceType(this.value, this.label);
}

/// 涨跌方向
enum TrendDirection {
  up, down, flat;

  static TrendDirection fromChange(double change) {
    if (change > 0) return up;
    if (change < 0) return down;
    return flat;
  }
}

/// 资产可见状态（首页资产卡片眼球切换）
enum AssetVisibleState {
  showAll(0),     // 显示金额 + 比例
  hideMoney(1),   // 隐藏金额
  hideRatio(2);   // 隐藏比例

  final int stateIndex;
  const AssetVisibleState(this.stateIndex);

  AssetVisibleState next() {
    return AssetVisibleState.values[(stateIndex + 1) % 3];
  }
}
