import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// 持仓列表项
class PositionItem {
  final int assetId;
  final int symbolId;
  final int assetType;
  final String shortName;
  final double marketValue;
  final double dayProfit;
  final double dayChangeRatio;
  final double holdProfit;
  final double holdChangeRatio;
  final bool isLatestNav;
  final List<IndicatorItem>? indicatorList;
  final LatestPriceInfo? latestPrice;
  final int? bookId;
  // 修改持仓编辑页预填字段（uni-app 行原始字段）
  final String uniqueSymbol;
  final String holdQuantity;
  final String holdCostAmount;
  final String comment;
  // 横滑表格新增字段（1:1 uni-app demoDisplayRows）
  final String symbolCode;
  final bool hasDcaPlan;
  final bool hasNote;
  final String fundTypeName;
  final double? increaseRatio;
  final double? holdingRatio;
  final int? holdDay;
  final double? breakEvenRate;
  // 扩展列（GET /asset/api/Asset/extended-columns 合并）
  final double? topHoldingsAvgChangeRate;
  final double? weekProfit;
  final double? weekProfitRate;
  final double? monthProfit;
  final double? monthProfitRate;
  final double? yearProfit;
  final double? yearProfitRate;

  const PositionItem({
    required this.assetId,
    required this.symbolId,
    required this.assetType,
    required this.shortName,
    required this.marketValue,
    required this.dayProfit,
    required this.dayChangeRatio,
    required this.holdProfit,
    required this.holdChangeRatio,
    this.isLatestNav = false,
    this.indicatorList,
    this.latestPrice,
    this.bookId,
    this.uniqueSymbol = '',
    this.holdQuantity = '',
    this.holdCostAmount = '',
    this.comment = '',
    this.symbolCode = '',
    this.hasDcaPlan = false,
    this.hasNote = false,
    this.fundTypeName = '',
    this.increaseRatio,
    this.holdingRatio,
    this.holdDay,
    this.breakEvenRate,
    this.topHoldingsAvgChangeRate,
    this.weekProfit,
    this.weekProfitRate,
    this.monthProfit,
    this.monthProfitRate,
    this.yearProfit,
    this.yearProfitRate,
  });

  factory PositionItem.fromJson(Map<String, dynamic> json) {
    final lp = json['latestPrice'] as Map<String, dynamic>?;
    final indicators = (json['indicators'] ?? json['indicatorList']) as List?;
    return PositionItem(
      assetId: json['assetId'] as int? ?? 0,
      symbolId: json['symbolId'] as int? ?? 0,
      assetType: json['assetType'] as int? ?? 3,
      shortName: (json['shortName'] ?? json['name'] ?? '--') as String,
      marketValue: _toNum(json['marketValue']) ?? 0,
      dayProfit: _toNum(json['dayProfit']) ?? 0,
      dayChangeRatio: _toNum(json['dayChangeRatio'] ?? lp?['chgRate']) ?? 0,
      holdProfit: _toNum(json['holdProfit']) ?? 0,
      holdChangeRatio: _toNum(json['holdChangeRatio']) ?? 0,
      isLatestNav: _toFlag(json['isLatestNav']),
      indicatorList: indicators
          ?.map((e) => IndicatorItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      latestPrice: lp != null ? LatestPriceInfo.fromJson(lp) : null,
      bookId: json['bookId'] as int?,
      uniqueSymbol: (json['uniqueSymbol'] ?? json['code'] ?? '').toString(),
      holdQuantity: (json['holdQuantity'] ?? json['quantity'] ?? '').toString(),
      holdCostAmount:
          (json['holdCostAmount'] ?? json['costAmount'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      symbolCode: (json['symbolCode'] ?? json['code'] ?? '').toString(),
      hasDcaPlan: _toFlag(json['hasDcaPlan']),
      hasNote: _toFlag(json['hasNote']),
      fundTypeName: (json['fundTypeName'] ?? '').toString(),
      increaseRatio: _toNum(json['increaseRatio']),
      holdingRatio: _toNum(json['holdingRatio']),
      holdDay: _toNum(json['holdDay'])?.toInt(),
      breakEvenRate: _toNum(json['breakEvenRate']),
      topHoldingsAvgChangeRate: _toNum(json['topHoldingsAvgChangeRate']),
      weekProfit: _toNum(json['weekProfit']),
      weekProfitRate: _toNum(json['weekProfitRate']),
      monthProfit: _toNum(json['monthProfit']),
      monthProfitRate: _toNum(json['monthProfitRate']),
      yearProfit: _toNum(json['yearProfit']),
      yearProfitRate: _toNum(json['yearProfitRate']),
    );
  }

  /// 合并扩展列字段（按 assetId / symbolId 对齐后生成新实例）
  PositionItem mergeExtended(Map<String, dynamic> ext) {
    return PositionItem(
      assetId: assetId,
      symbolId: symbolId,
      assetType: assetType,
      shortName: shortName,
      marketValue: marketValue,
      dayProfit: dayProfit,
      dayChangeRatio: dayChangeRatio,
      holdProfit: holdProfit,
      holdChangeRatio: holdChangeRatio,
      isLatestNav: isLatestNav,
      indicatorList: indicatorList,
      latestPrice: latestPrice,
      bookId: bookId,
      uniqueSymbol: uniqueSymbol,
      holdQuantity: holdQuantity,
      holdCostAmount: holdCostAmount,
      comment: comment,
      symbolCode: symbolCode,
      hasDcaPlan: hasDcaPlan,
      hasNote: hasNote,
      fundTypeName: fundTypeName,
      increaseRatio: increaseRatio,
      holdingRatio: holdingRatio,
      holdDay: holdDay,
      breakEvenRate: breakEvenRate,
      topHoldingsAvgChangeRate:
          _toNum(ext['topHoldingsAvgChangeRate']) ?? topHoldingsAvgChangeRate,
      weekProfit: _toNum(ext['weekProfit']) ?? weekProfit,
      weekProfitRate: _toNum(ext['weekProfitRate']) ?? weekProfitRate,
      monthProfit: _toNum(ext['monthProfit']) ?? monthProfit,
      monthProfitRate: _toNum(ext['monthProfitRate']) ?? monthProfitRate,
      yearProfit: _toNum(ext['yearProfit']) ?? yearProfit,
      yearProfitRate: _toNum(ext['yearProfitRate']) ?? yearProfitRate,
    );
  }

  /// 最新涨跌幅 (1:1 uni-app getLatestChgRate: chgRate ?? changeRatio ?? increaseRatio)
  double get latestChgRate => latestChgRateOrNull ?? dayChangeRatio;

  double? get latestChgRateOrNull => latestPrice?.chgRate ?? increaseRatio;

  /// 持有份额/成本数值（接口字段是数字，本地保留字符串供编辑页预填）
  double? get holdQuantityNum => _toNum(holdQuantity);
  double? get holdCostAmountNum => _toNum(holdCostAmount);

  /// 第一个关联指标
  IndicatorItem? get firstIndicator {
    if (indicatorList != null && indicatorList!.isNotEmpty) {
      return indicatorList![0];
    }
    return latestPrice?.indicatorList?.isNotEmpty == true
        ? latestPrice!.indicatorList![0]
        : null;
  }

  /// 关联板块名（取前 7 字，1:1 uni-app getFirstIndicatorName）
  String get firstIndicatorName {
    final name = firstIndicator?.name;
    if (name == null || name.isEmpty) return '-';
    return name.length > 7 ? name.substring(0, 7) : name;
  }

  /// 是否当日更新
  bool get isUpdated {
    if (isLatestNav) {
      return true;
    }
    if (latestPrice?.priceType != 2) {
      return false;
    }
    final lt = latestPrice?.latestTimeMs;
    if (lt == null || lt == 0) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    const window = 33 * 60 * 60 * 1000;
    return now >= lt && now < lt + window;
  }

  /// 是否昨日净值
  bool get isYesterday {
    if (latestPrice?.priceType != 2) {
      return false;
    }
    final lt = latestPrice?.latestTimeMs;
    return lt != null && lt > 0 && lt < DateTime.now().millisecondsSinceEpoch;
  }

  /// 获取净值日期标签
  String get latestTimeLabel {
    final raw = latestPrice?.latestTime ?? '';
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(raw);
    if (match == null) {
      return '';
    }
    final parts = match.group(0)!.split('-');
    return '${parts[1]}-${parts[2]}';
  }

  /// QDII 净值日期前缀（latestPrice.latestNavDate，MM-DD）
  String get navDateLabel {
    final raw = latestPrice?.latestNavDate ?? '';
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(raw);
    if (match == null) return '';
    return match.group(0)!.substring(5);
  }

  /// 是否 QDII（海外基金净值 T+1 滞后）
  bool get isQdii => fundTypeName.toUpperCase().contains('QDII');

  static bool _toFlag(dynamic v) {
    if (v == true) return true;
    if (v is num) return v == 1;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// 关联指标
class IndicatorItem {
  final String? name;
  final String? shortName;
  final double? changeRatio;

  const IndicatorItem({this.name, this.shortName, this.changeRatio});

  factory IndicatorItem.fromJson(Map<String, dynamic> json) {
    return IndicatorItem(
      name: json['name'] as String?,
      shortName: json['shortName'] as String?,
      changeRatio: _toNum(json['changeRatio'] ?? json['chgRate']),
    );
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// 最新价格信息
class LatestPriceInfo {
  final double? latestPrice;
  final double? preClose;
  final double? chgRate;
  final int? priceType;
  final String? latestTime;
  final String? latestNavDate;
  final List<IndicatorItem>? indicatorList;

  const LatestPriceInfo({
    this.latestPrice,
    this.preClose,
    this.chgRate,
    this.priceType,
    this.latestTime,
    this.latestNavDate,
    this.indicatorList,
  });

  int? get latestTimeMs {
    if (latestTime == null) return null;
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(latestTime!);
    final dateStr = match?.group(0) ?? latestTime!;
    return DateTime.tryParse(
      dateStr.replaceAll('-', '/'),
    )?.millisecondsSinceEpoch;
  }

  factory LatestPriceInfo.fromJson(Map<String, dynamic> json) {
    final indicators = json['indicatorList'] as List?;
    return LatestPriceInfo(
      latestPrice: _toNum(json['latestPrice']),
      preClose: _toNum(json['preClose']),
      chgRate: _toNum(json['chgRate'] ?? json['changeRatio']),
      priceType: json['priceType'] as int?,
      latestTime: json['latestTime'] as String?,
      latestNavDate: json['latestNavDate'] as String?,
      indicatorList: indicators
          ?.map((e) => IndicatorItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// 账本项
class BookItem {
  final int bookId;
  final String bookName;
  const BookItem({required this.bookId, required this.bookName});
}

/// 账户汇总卡片（GET /asset/api/Asset/overview/cards）
class OverviewCard {
  final int bookId;
  final String bookName;
  final String iconKey;
  final double assetAmount;
  final double holdingProfit;
  final double holdingProfitRate;
  final double dayProfit;
  final double dayProfitRate;
  final int riseCount;
  final int fallCount;
  final List<OverviewTrendPoint> trend;

  const OverviewCard({
    required this.bookId,
    required this.bookName,
    this.iconKey = '',
    this.assetAmount = 0,
    this.holdingProfit = 0,
    this.holdingProfitRate = 0,
    this.dayProfit = 0,
    this.dayProfitRate = 0,
    this.riseCount = 0,
    this.fallCount = 0,
    this.trend = const [],
  });

  factory OverviewCard.fromJson(Map<String, dynamic> json) {
    final trendList = json['trend'] as List?;
    return OverviewCard(
      bookId: _toInt(json['bookId']) ?? 0,
      bookName: (json['bookName'] ?? json['name'] ?? '').toString(),
      iconKey: (json['iconKey'] ?? '').toString(),
      assetAmount: _toNum(json['assetAmount'] ?? json['totalMarketValue']) ?? 0,
      holdingProfit: _toNum(json['holdingProfit']) ?? 0,
      holdingProfitRate: _toNum(json['holdingProfitRate']) ?? 0,
      dayProfit: _toNum(json['dayProfit']) ?? 0,
      dayProfitRate: _toNum(json['dayProfitRate']) ?? 0,
      riseCount: _toInt(json['riseCount']) ?? 0,
      fallCount: _toInt(json['fallCount']) ?? 0,
      trend: trendList
              ?.map((e) => OverviewTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// 汇总卡片迷你走势点
class OverviewTrendPoint {
  final String time;
  final int timestamp;
  final double? dayProfitRate;
  final double? assetAmount;

  const OverviewTrendPoint({
    this.time = '',
    this.timestamp = 0,
    this.dayProfitRate,
    this.assetAmount,
  });

  factory OverviewTrendPoint.fromJson(Map<String, dynamic> json) {
    double? numOf(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return OverviewTrendPoint(
      time: (json['time'] ?? '').toString(),
      timestamp: (json['timestamp'] is num)
          ? (json['timestamp'] as num).toInt()
          : int.tryParse('${json['timestamp']}') ?? 0,
      dayProfitRate: numOf(json['dayProfitRate']),
      assetAmount: numOf(json['assetAmount']),
    );
  }
}

/// 滚动通知条单条内容（GET /asset/api/ScrollContent/current items[]）
class FeedNoticeItem {
  final String content;
  final int scrollType; // 1=上下滚动 2=左右滚动 3=静止
  final String linkType; // 1=内页 2=公众号链接
  final String linkUrl;

  const FeedNoticeItem({
    required this.content,
    this.scrollType = 3,
    this.linkType = '',
    this.linkUrl = '',
  });
}

/// 资产可见级别 — 1:1 复刻 uni-app assetVisible (0~4)
/// 0=全部显示, 1=隐藏持有金额, 2=再隐藏收益金额, 3=再隐藏收益率, 4=再隐藏基金名称
class AssetVisibleLevel {
  AssetVisibleLevel._();
  static const showAll = 0;
  static const hideHoldAmount = 1;
  static const hideIncomeAmount = 2;
  static const hideIncomeRate = 3;
  static const hideFundName = 4;
}

/// 表格展示模式: 0=普通, 1=简洁, 2=极简
enum TableShowMode { normal, compact, minimal }

/// 列表字体档位 — 1:1 复刻 uni-app .font-standard CSS 覆盖（index.vue 尾部）
/// 存储 fontSizeMode：0=标准（缩小一档）1=大号（默认，存量视觉不变）
/// 数值单位 px（rpx÷2），大号口径 = index.vue 静态字号
class PositionFontScale {
  final double cellMain; // .holding-cell__rate 主行
  final double cellMainSmall; // .holding-cell__rate--small（|持有收益|≥100000 再降档）
  final double cellSub; // .holding-profit__mains 副行
  final double nameMain; // .holding-name__main 基金名
  final double nameSub; // .holding-name__sub 代码/持有金额
  final double placeholder; // .hsw-placeholder 占位列主行
  final double placeholderSub; // .hsw-placeholder--sub 占位列副行
  final double indicatorName; // .indicator-name-text 板块名
  final double indicatorNameXl; // .indicator-name-text--xl（≥8 字，两档相同）
  final double yesterday; // .yesterday-jzhi 昨日净值日期
  final double badge; // .updateditem / .dca-plan-badge 徽章
  final double navDate; // .hsw-nav-date QDII 净值日期前缀

  const PositionFontScale._({
    required this.cellMain,
    required this.cellMainSmall,
    required this.cellSub,
    required this.nameMain,
    required this.nameSub,
    required this.placeholder,
    required this.placeholderSub,
    required this.indicatorName,
    required this.indicatorNameXl,
    required this.yesterday,
    required this.badge,
    required this.navDate,
  });

  /// 大号（默认）：index.vue 静态字号
  static const large = PositionFontScale._(
    cellMain: 16, // 32rpx
    cellMainSmall: 14, // 28rpx
    cellSub: 11, // 22rpx
    nameMain: 14, // 28rpx
    nameSub: 10.5, // 21rpx
    placeholder: 14, // 28rpx
    placeholderSub: 10, // 20rpx
    indicatorName: 9, // 18rpx
    indicatorNameXl: 8, // 16rpx
    yesterday: 10, // 20rpx
    badge: 9, // 18rpx
    navDate: 9, // 18rpx
  );

  /// 标准（缩小一档）：.font-standard CSS 覆盖值
  static const standard = PositionFontScale._(
    cellMain: 15, // 30rpx
    cellMainSmall: 13, // 26rpx
    cellSub: 10, // 20rpx
    nameMain: 13, // 26rpx
    nameSub: 9.5, // 19rpx
    placeholder: 12, // 24rpx
    placeholderSub: 8, // 16rpx
    indicatorName: 9, // 18rpx（标准档不变）
    indicatorNameXl: 8, // 16rpx
    yesterday: 8, // 16rpx
    badge: 7, // 14rpx
    navDate: 7, // 14rpx
  );

  /// fontSizeMode：0=标准，其余（含缺失）=大号（对齐 uni-app normalizeFontSizeMode）
  static PositionFontScale of(bool standard) =>
      standard ? PositionFontScale.standard : PositionFontScale.large;
}

/// 持仓页状态
class PositionState {
  final List<BookItem> books;
  final int tabIndex; // 账本 tab 统一索引：0..bookNames.length-1 为滚动区，overviewTabIndex 为账户汇总
  final List<PositionItem> items;
  final double totalMarketValue;
  final double totalDayProfit;
  final double totalDayChangeRatio;
  final int assetVisible; // 0~4，见 AssetVisibleLevel
  final bool isLoading;
  final String? refreshTime;
  final bool showRatioTip;
  final bool showNotOpened; // 刷新时非交易日提示「尚未开盘」
  final bool showProfitRatio; // 当日总收益主显 金额/收益率 切换（持久化）
  final String curTradeDate; // 接口返回的当前交易日 (yyyy-MM-dd)
  final String latestNavDate; // 最新净值列日期
  final String extendedCurTradeDate; // 扩展列日期
  final TableShowMode tableMode;
  final String sortField;
  final String sortOrder; // 'asc' or 'desc'
  final bool isLoggedIn;
  final String? errorMessage;
  // ===== 新版页面（positionv1 横滑表格 + 账户汇总）=====
  final bool allBookVisible; // positionAllBookVisible：账本 tab 是否含「全部」
  final List<OverviewCard> overviewCards;
  final bool overviewLoading;
  // 汇总 tab 资产卡统计（GET /asset/api/Asset 无 bookId）
  final double overviewTotalMarketValue;
  final double overviewTotalDayProfit;
  final double overviewTotalDayChangeRatio;
  final FeedNoticeItem? feedNotice; // 当前展示的滚动通知（null=不显示）
  final String fundGroupCountText; // 基金群胶囊计数文字
  final bool marketCubeEnabled; // 公告 position=3 控制「市场魔方」胶囊
  // 表头管理配置（GET /usercenter/api/User/holding-columns）
  final List<String>? columnKeys; // null=默认全列；否则按配置顺序的可见列 key
  final bool showFundCode; // 名称副行显示基金代码（否则显示持有金额）
  final bool showHoldingAmount;
  final bool listFontStandard; // fontSizeMode==0：列表字体「标准」档（缩小一档）

  const PositionState({
    this.books = const [],
    this.tabIndex = -1, // -1=未初始化：loadData 时按登录态确定（游客 0，登录 allBookVisible?1:0）
    this.items = const [],
    this.totalMarketValue = 0,
    this.totalDayProfit = 0,
    this.totalDayChangeRatio = 0,
    this.assetVisible = 0,
    this.isLoading = false,
    this.refreshTime,
    this.showRatioTip = false,
    this.showNotOpened = false,
    this.showProfitRatio = false,
    this.curTradeDate = '',
    this.latestNavDate = '',
    this.extendedCurTradeDate = '',
    this.tableMode = TableShowMode.normal,
    this.sortField = '',
    this.sortOrder = 'desc',
    this.isLoggedIn = false,
    this.errorMessage,
    this.allBookVisible = true,
    this.overviewCards = const [],
    this.overviewLoading = false,
    this.overviewTotalMarketValue = 0,
    this.overviewTotalDayProfit = 0,
    this.overviewTotalDayChangeRatio = 0,
    this.feedNotice,
    this.fundGroupCountText = '已有--入群',
    this.marketCubeEnabled = false,
    this.columnKeys,
    this.showFundCode = false,
    this.showHoldingAmount = true,
    this.listFontStandard = false,
  });

  PositionState copyWith({
    List<BookItem>? books,
    int? tabIndex,
    List<PositionItem>? items,
    double? totalMarketValue,
    double? totalDayProfit,
    double? totalDayChangeRatio,
    int? assetVisible,
    bool? isLoading,
    String? refreshTime,
    bool? showRatioTip,
    bool? showNotOpened,
    bool? showProfitRatio,
    String? curTradeDate,
    String? latestNavDate,
    String? extendedCurTradeDate,
    TableShowMode? tableMode,
    String? sortField,
    String? sortOrder,
    bool? isLoggedIn,
    String? errorMessage,
    bool? allBookVisible,
    List<OverviewCard>? overviewCards,
    bool? overviewLoading,
    double? overviewTotalMarketValue,
    double? overviewTotalDayProfit,
    double? overviewTotalDayChangeRatio,
    FeedNoticeItem? Function()? feedNotice,
    String? fundGroupCountText,
    bool? marketCubeEnabled,
    List<String>? Function()? columnKeys,
    bool? showFundCode,
    bool? showHoldingAmount,
    bool? listFontStandard,
  }) => PositionState(
    books: books ?? this.books,
    tabIndex: tabIndex ?? this.tabIndex,
    items: items ?? this.items,
    totalMarketValue: totalMarketValue ?? this.totalMarketValue,
    totalDayProfit: totalDayProfit ?? this.totalDayProfit,
    totalDayChangeRatio: totalDayChangeRatio ?? this.totalDayChangeRatio,
    assetVisible: assetVisible ?? this.assetVisible,
    isLoading: isLoading ?? this.isLoading,
    refreshTime: refreshTime ?? this.refreshTime,
    showRatioTip: showRatioTip ?? this.showRatioTip,
    showNotOpened: showNotOpened ?? this.showNotOpened,
    showProfitRatio: showProfitRatio ?? this.showProfitRatio,
    curTradeDate: curTradeDate ?? this.curTradeDate,
    latestNavDate: latestNavDate ?? this.latestNavDate,
    extendedCurTradeDate: extendedCurTradeDate ?? this.extendedCurTradeDate,
    tableMode: tableMode ?? this.tableMode,
    sortField: sortField ?? this.sortField,
    sortOrder: sortOrder ?? this.sortOrder,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    errorMessage: errorMessage,
    allBookVisible: allBookVisible ?? this.allBookVisible,
    overviewCards: overviewCards ?? this.overviewCards,
    overviewLoading: overviewLoading ?? this.overviewLoading,
    overviewTotalMarketValue:
        overviewTotalMarketValue ?? this.overviewTotalMarketValue,
    overviewTotalDayProfit: overviewTotalDayProfit ?? this.overviewTotalDayProfit,
    overviewTotalDayChangeRatio:
        overviewTotalDayChangeRatio ?? this.overviewTotalDayChangeRatio,
    feedNotice: feedNotice != null ? feedNotice() : this.feedNotice,
    fundGroupCountText: fundGroupCountText ?? this.fundGroupCountText,
    marketCubeEnabled: marketCubeEnabled ?? this.marketCubeEnabled,
    columnKeys: columnKeys != null ? columnKeys() : this.columnKeys,
    showFundCode: showFundCode ?? this.showFundCode,
    showHoldingAmount: showHoldingAmount ?? this.showHoldingAmount,
    listFontStandard: listFontStandard ?? this.listFontStandard,
  );

  /// 列表字体档位（大号/标准）
  PositionFontScale get fontScale => PositionFontScale.of(listFontStandard);

  /// 账本名称列表（滚动区；受 positionAllBookVisible 控制是否含「全部」）
  List<String> get bookNames =>
      allBookVisible ? ['全部', ...books.map((b) => b.bookName)] : books.map((b) => b.bookName).toList();

  /// 账户汇总 tab 的索引（固定在滚动列表之后）
  int get overviewTabIndex => bookNames.length;

  bool get isOverviewTab => tabIndex == overviewTabIndex;

  /// 当前选中的 bookId (null=全部/汇总)
  int? get currentBookId {
    if (isOverviewTab) return null;
    final offset = allBookVisible ? 1 : 0;
    if (allBookVisible && tabIndex == 0) return null;
    final i = tabIndex - offset;
    if (i < 0 || i >= books.length) return null;
    return books[i].bookId;
  }

  // ---- 隐私级别派生 (1:1 uni-app hideXxx computed) ----
  bool get hideHoldAmount => assetVisible >= AssetVisibleLevel.hideHoldAmount;
  bool get hideIncomeAmount =>
      assetVisible >= AssetVisibleLevel.hideIncomeAmount;
  bool get hideIncomeRate => assetVisible >= AssetVisibleLevel.hideIncomeRate;
  bool get hideFundName => assetVisible >= AssetVisibleLevel.hideFundName;

  /// 表头日期标签 (MM-dd)：优先接口 curTradeDate，否则最近一个工作日
  /// (uni-app 用 chinese-days 跳过法定节假日，这里仅跳过周末 —— 见迁移报告)
  String get headerDateLabel => _dateLabel(curTradeDate);

  /// 最新净值列日期标签
  String get latestNavDateLabel =>
      latestNavDate.isNotEmpty ? _dateLabel(latestNavDate) : headerDateLabel;

  /// 扩展列日期标签
  String get extendedDateLabel => extendedCurTradeDate.isNotEmpty
      ? _dateLabel(extendedCurTradeDate)
      : headerDateLabel;

  String _dateLabel(String value) {
    final d = _parseDate(value) ?? _lastWeekday(DateTime.now());
    final m = '${d.month}'.padLeft(2, '0');
    final day = '${d.day}'.padLeft(2, '0');
    return '$m-$day';
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(value);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return DateTime.tryParse(value);
  }

  static DateTime _lastWeekday(DateTime from) {
    var d = from;
    for (var i = 0; i < 15; i++) {
      if (d.weekday >= DateTime.monday && d.weekday <= DateTime.friday) {
        return d;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return from;
  }

  /// 排序后的列表 — 1:1 uni-app getSortedMergedList：
  /// isLatestNav 项置顶，再按排序字段排，同值按原 index 稳定
  List<PositionItem> get sortedItems {
    final indexed = <int, PositionItem>{};
    for (var i = 0; i < items.length; i++) {
      indexed[i] = items[i];
    }
    final keys = indexed.keys.toList();
    keys.sort((ia, ib) {
      final a = indexed[ia]!;
      final b = indexed[ib]!;
      final updatedDiff = (b.isLatestNav ? 1 : 0) - (a.isLatestNav ? 1 : 0);
      if (updatedDiff != 0) return updatedDiff;
      if (sortField.isEmpty || sortField == 'sort') return ia - ib;
      final va = _sortValue(a, sortField);
      final vb = _sortValue(b, sortField);
      final diff = sortOrder == 'asc' ? va - vb : vb - va;
      if (diff != 0) return diff.sign.toInt();
      return ia - ib;
    });
    return keys.map((i) => indexed[i]!).toList();
  }

  /// 1:1 uni-app getSortValue（increaseRatio=首个关联板块涨幅；latestPrice.chgRate 走回退链）
  static double _sortValue(PositionItem item, String field) {
    switch (field) {
      case 'increaseRatio':
        return item.firstIndicator?.changeRatio ?? 0;
      case 'latestPrice.chgRate':
        return item.latestChgRateOrNull ?? 0;
      case 'latestPrice.latestPrice':
        return item.latestPrice?.latestPrice ?? 0;
      case 'dayProfit':
        return item.dayProfit;
      case 'holdProfit':
        return item.holdProfit;
      case 'dayChangeRatio':
        return item.dayChangeRatio;
      case 'topHoldingsAvgChangeRate':
        return item.topHoldingsAvgChangeRate ?? 0;
      case 'weekProfit':
        return item.weekProfit ?? 0;
      case 'monthProfit':
        return item.monthProfit ?? 0;
      case 'yearProfitRate':
        return item.yearProfitRate ?? 0;
      case 'marketValue':
        return item.marketValue;
      case 'holdingRatio':
        return item.holdingRatio ?? 0;
      case 'holdQuantity':
        return item.holdQuantityNum ?? 0;
      case 'holdCostAmount':
        return item.holdCostAmountNum ?? 0;
      case 'holdDay':
        return (item.holdDay ?? 0).toDouble();
      case 'breakEvenRate':
        return item.breakEvenRate ?? 0;
      default:
        return 0;
    }
  }

  /// 是否基金市场休市（近似：周末或 9:00-15:00 之外）
  bool get isFundMarketClosed {
    final now = DateTime.now();
    final day = now.weekday;
    if (day == 6 || day == 7) return true;
    final hour = now.hour;
    if (hour < 9 || hour >= 15) return true;
    return false;
  }
}

/// 持仓页 Provider — 1:1 复刻 uni-app pages/positionv1/index.vue 数据流
class PositionNotifier extends StateNotifier<PositionState> {
  final ApiClient _api = ApiClient();

  /// 匿名请求通道（不带拦截器）：基金群人数等匿名接口失败/401 时
  /// 不能触发 ErrorInterceptor 的全局跳登录（对齐 uni-app 用裸 uni.request）
  final Dio _anonDio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  PositionNotifier() : super(const PositionState()) {
    _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getInt('tableShowMode') ?? 0;
    // 1:1 uni-app positionShowProfitRatio 缓存
    final showRatio = prefs.getBool('positionShowProfitRatio') ?? false;
    final allBookVisible = prefs.getBool('positionAllBookVisible') ?? true;
    // 1:1 uni-app positionHoldingSort {field, order} 持久化
    final sortField = prefs.getString('positionHoldingSortField') ?? '';
    final sortOrder = prefs.getString('positionHoldingSortOrder') ?? 'desc';
    // 1:1 uni-app fontSizeMode（0=标准 1=大号；缺失/非法按大号）+ fontSizeModeChanged 事件
    final listFontStandard = (prefs.getInt('fontSizeMode') ?? 1) == 0;
    state = state.copyWith(
      tableMode: TableShowMode.values[mode.clamp(0, 2)],
      showProfitRatio: showRatio,
      allBookVisible: allBookVisible,
      sortField: sortField,
      sortOrder: sortOrder == 'asc' ? 'asc' : 'desc',
      listFontStandard: listFontStandard,
    );
  }

  Future<void> _saveTableMode(TableShowMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tableShowMode', mode.index);
  }

  // ==================== API 调用 ====================

  /// 获取账本列表
  Future<List<BookItem>> _fetchBooks() async {
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final data = res.data;
      List list = [];
      if (data is List) {
        list = data;
      } else if (data != null && data['data'] is List) {
        list = data['data'];
      } else if (data != null && data['list'] is List) {
        list = data['list'];
      }
      return list
          .map(
            (b) => BookItem(
              bookId: b['bookId'] as int? ?? 0,
              bookName: b['bookName'] as String? ?? b['name'] as String? ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取资产列表（含扩展列合并）
  Future<void> _fetchAssets(int? bookId) async {
    try {
      final res = await _api.get(
        ApiEndpoints.assetListV2,
        queryParameters: bookId != null ? {'bookId': bookId} : null,
      );
      final data = res.data;
      if (data == null) return;
      Map<String, dynamic> payload;
      if (data['data'] is Map) {
        payload = data['data'] as Map<String, dynamic>;
      } else {
        payload = data as Map<String, dynamic>? ?? {};
      }

      final list =
          (payload['list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final items = list.map((e) => PositionItem.fromJson(e)).toList();
      final totalMarketValue = _toNum(payload['totalMarketValue']) ?? 0;
      final totalDayProfit = _toNum(payload['totalDayProfit']) ?? 0;
      // 1:1 uni-app：接口已返回百分比数值，前端直接展示，不再 ×100
      final totalDayChangeRatio = _toNum(payload['totalDayChangeRatio']) ?? 0;
      final curTradeDate = payload['curTradeDate'] as String? ?? '';
      final latestNavDate = payload['latestNavDate'] as String? ?? '';

      state = state.copyWith(
        items: items,
        totalMarketValue: totalMarketValue,
        totalDayProfit: totalDayProfit,
        totalDayChangeRatio: totalDayChangeRatio,
        curTradeDate: curTradeDate,
        latestNavDate: latestNavDate,
      );
      // 扩展列合并（重仓均涨幅/本周/本月/今年）
      unawaited(_fetchExtendedColumns(bookId));
    } catch (_) {}
  }

  /// 获取扩展列并按 assetId（有 bookId）或 symbolId 对齐合并
  Future<void> _fetchExtendedColumns(int? bookId) async {
    try {
      final res = await _api.get(
        ApiEndpoints.assetExtendedColumns,
        queryParameters: bookId != null ? {'bookId': bookId} : null,
      );
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>? ?? {});
      final list =
          (payload['list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final extDate = payload['curTradeDate'] as String? ?? '';
      if (!mounted) return;
      final current = List<PositionItem>.from(state.items);
      final merged = current.map((item) {
        Map<String, dynamic>? ext;
        for (final e in list) {
          final matched = bookId != null
              ? e['assetId'] == item.assetId
              : e['symbolId'] == item.symbolId;
          if (matched) {
            ext = e;
            break;
          }
        }
        return ext == null ? item : item.mergeExtended(ext);
      }).toList();
      state = state.copyWith(items: merged, extendedCurTradeDate: extDate);
    } catch (_) {}
  }

  /// 表头管理配置（显隐 + 顺序 + 基金代码/持有金额开关）
  Future<void> _fetchHoldingColumns() async {
    try {
      final res = await _api.get(ApiEndpoints.holdingColumns);
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>? ?? {});
      final columns = (payload['columns'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      List<String>? keys;
      if (columns.isNotEmpty) {
        // 后端 key → 前端列 key 别名：primarySector→indicator / latestPrice→latestNav
        const alias = {'primarySector': 'indicator', 'latestPrice': 'latestNav'};
        keys = columns
            .where((c) => c['visible'] != false)
            .map((c) => alias[c['key']] ?? c['key'])
            .whereType<String>()
            .toList();
      }
      if (!mounted) return;
      state = state.copyWith(
        columnKeys: () => keys,
        showFundCode: payload['showFundCode'] == true,
        showHoldingAmount: payload['showHoldingAmount'] != false,
      );
    } catch (_) {}
  }

  /// 汇总卡片
  Future<void> _fetchOverviewCards() async {
    state = state.copyWith(overviewLoading: true);
    try {
      final res = await _api.get(ApiEndpoints.assetOverviewCards);
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : []);
      final cards = list
          .whereType<Map<String, dynamic>>()
          .map(OverviewCard.fromJson)
          .toList();
      if (!mounted) return;
      state = state.copyWith(overviewCards: cards, overviewLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(overviewLoading: false);
    }
  }

  /// 汇总统计（全部账本合计）
  Future<void> _fetchOverviewStats() async {
    try {
      final res = await _api.get(ApiEndpoints.assetListV2);
      final data = res.data;
      if (data == null) return;
      final payload = (data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>? ?? {});
      if (!mounted) return;
      state = state.copyWith(
        overviewTotalMarketValue: _toNum(payload['totalMarketValue']) ?? 0,
        overviewTotalDayProfit: _toNum(payload['totalDayProfit']) ?? 0,
        overviewTotalDayChangeRatio:
            _toNum(payload['totalDayChangeRatio']) ?? 0,
      );
    } catch (_) {}
  }

  /// 基金群人数（匿名接口，1:1 uni-app useCommunityGroupCounter）
  Future<void> _loadFundGroupCount() async {
    try {
      final res = await _anonDio.get(ApiEndpoints.communityGroupCount);
      final data = res.data;
      if (data is Map && data['code'] == 200) {
        final count = data['data']?['currentCount'];
        if (count != null) {
          final text = '$count'.replaceFirst(RegExp(r'^0+(?=\d)'), '');
          if (!mounted) return;
          state = state.copyWith(fundGroupCountText: '已有$text入群');
        }
      }
    } catch (_) {}
  }

  /// 市场魔方开关（公告 position=3，1:1 uni-app loadDarkMarketNotice）
  Future<void> _loadMarketCubeSwitch() async {
    try {
      final res = await _api.get(
        ApiEndpoints.announcement,
        queryParameters: {'position': 3, 'limit': 1},
      );
      final data = res.data;
      final payload = data is Map && data.containsKey('data')
          ? data['data']
          : data;
      final items = payload is List
          ? payload
          : (payload is Map && payload['data'] is List
              ? payload['data'] as List
              : const []);
      final enabled =
          items.any((item) => item is Map && _toInt(item['position']) == 3);
      if (!mounted) return;
      state = state.copyWith(marketCubeEnabled: enabled);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(marketCubeEnabled: false);
    }
  }

  /// 滚动通知条（slotCode=position_feed；失败/为空时隐藏）
  Future<void> _loadFeedNotice() async {
    try {
      final res = await _api.get(
        ApiEndpoints.scrollContentCurrent,
        queryParameters: {'slotCode': 'position_feed'},
      );
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>? ?? {});
      final rawItems = (payload['items'] is List && (payload['items'] as List).isNotEmpty
              ? payload['items'] as List
              : (payload['item'] != null ? [payload['item']] : []))
          .whereType<Map<String, dynamic>>()
          .where((it) => '${it['content'] ?? ''}'.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      if (payload['enabled'] != true || rawItems.isEmpty) {
        state = state.copyWith(feedNotice: () => null);
        return;
      }
      // 1:1 uni-app consumeScrollNoticeIndex：冷启动/切回前台前进一步，配置变化归零
      final configVersion = '${payload['configVersion'] ?? ''}';
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getString('scrollNoticeVer_position_feed') ?? '';
      var index = 0;
      if (savedVersion == configVersion) {
        index = (prefs.getInt('scrollNoticeIdx_position_feed') ?? -1) + 1;
      }
      index = index % rawItems.length;
      await prefs.setString('scrollNoticeVer_position_feed', configVersion);
      await prefs.setInt('scrollNoticeIdx_position_feed', index);
      final item = rawItems[index];
      if (!mounted) return;
      state = state.copyWith(
        feedNotice: () => FeedNoticeItem(
          content: '${item['content']}'.trim(),
          scrollType: _toInt(item['scrollType']) ?? 3,
          linkType: '${item['linkType'] ?? ''}',
          linkUrl: '${item['linkUrl'] ?? ''}',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(feedNotice: () => null);
    }
  }

  /// 关闭滚动通知条（仅本次会话隐藏，1:1 uni-app closeFeedNotice）
  void dismissFeedNotice() {
    state = state.copyWith(feedNotice: () => null);
  }

  /// 加载全部数据 (queryPositionPaging)
  Future<void> loadData({bool showRefreshTip = false}) async {
    state = state.copyWith(isLoading: true);

    // 匿名即可用的区块（游客也加载）：基金群人数 / 市场魔方开关 / 滚动通知条
    unawaited(_loadFundGroupCount());
    unawaited(_loadMarketCubeSwitch());
    unawaited(_loadFeedNotice());

    // 检查登录
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = token != null && token.isNotEmpty;
    if (!isLoggedIn) {
      // 游客：不发需鉴权请求（避免 401 全局跳登录），落在「全部」tab
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        items: [],
        books: [],
        tabIndex: 0,
        overviewCards: [],
      );
      return;
    }

    try {
      final books = await _fetchBooks();
      final allBookVisible = prefs.getBool('positionAllBookVisible') ?? true;

      // 初始化/矫正 tabIndex
      var tabIdx = state.tabIndex;
      if (tabIdx < 0) tabIdx = allBookVisible ? 1 : 0;
      final overviewIdx = books.length + (allBookVisible ? 1 : 0);
      if (tabIdx > overviewIdx) tabIdx = 0;

      state = state.copyWith(
        books: books,
        tabIndex: tabIdx,
        isLoggedIn: true,
        allBookVisible: allBookVisible,
        // 1:1 uni-app fontSizeModeChanged：页面存活期间档位变化随下次加载生效
        listFontStandard: (prefs.getInt('fontSizeMode') ?? 1) == 0,
      );

      final currentBook = state.currentBookId;
      if (state.isOverviewTab) {
        await Future.wait([_fetchOverviewCards(), _fetchOverviewStats()]);
      } else {
        await _fetchAssets(currentBook);
      }
      unawaited(_fetchHoldingColumns());

      if (showRefreshTip) {
        final now = DateTime.now();
        final h = '${now.hour}'.padLeft(2, '0');
        final m = '${now.minute}'.padLeft(2, '0');
        final s = '${now.second}'.padLeft(2, '0');
        // 1:1 uni-app onRefresh: 非交易日显示「尚未开盘」(chinese-days 法定节假日
        // 判断在 Flutter 端用周末近似)，3 秒后提示自动消失
        final notOpened = !_isFundTradingDay(now);
        state = state.copyWith(
          refreshTime: '$h:$m:$s',
          showRatioTip: true,
          showNotOpened: notOpened,
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            state = state.copyWith(showRatioTip: false, showNotOpened: false);
          }
        });
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 是否基金交易日 (近似：仅排除周末；法定节假日见迁移报告)
  bool _isFundTradingDay(DateTime d) {
    return d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;
  }

  /// 下拉刷新（游客直接结束，不发请求）
  Future<void> refresh() async {
    if (!state.isLoggedIn) return;
    await loadData(showRefreshTip: true);
  }

  /// 切换账本 — 1:1 uni-app watch(taberIndex)：汇总 tab 拉汇总数据，其余只重拉资产列表
  void selectTab(int index) {
    if (index == state.tabIndex) return;
    state = state.copyWith(tabIndex: index);
    if (state.isOverviewTab) {
      _fetchOverviewCards();
      _fetchOverviewStats();
    } else {
      _fetchAssets(state.currentBookId);
    }
  }

  /// 汇总卡片点击 → 切换到对应账本 tab（1:1 uni-app handleOverviewCardSelect）
  /// 返回 false 表示账本不存在
  bool selectBookTabById(int bookId) {
    final idx = state.books.indexWhere((b) => b.bookId == bookId);
    if (idx < 0) return false;
    final offset = state.allBookVisible ? 1 : 0;
    selectTab(idx + offset);
    return true;
  }

  // ==================== 交互 ====================

  /// 设置资产可见级别 (0~4) — 1:1 uni-app selectAssetVisibleMode
  void setAssetVisible(int level) {
    state = state.copyWith(assetVisible: level.clamp(0, 4));
  }

  /// 切换当日总收益 金额/收益率 主显 — 1:1 uni-app toggleProfitDisplay（持久化）
  Future<void> toggleProfitDisplay() async {
    final next = !state.showProfitRatio;
    state = state.copyWith(showProfitRatio: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('positionShowProfitRatio', next);
  }

  /// 切换排序 — 1:1 复刻 uni-app toggleMetalSort: desc → asc → cleared → desc（持久化）
  Future<void> toggleSort(String field) async {
    String nextField;
    String nextOrder;
    if (state.sortField == field) {
      if (state.sortOrder == 'desc') {
        nextField = field;
        nextOrder = 'asc';
      } else if (state.sortOrder == 'asc') {
        nextField = '';
        nextOrder = '';
      } else {
        nextField = field;
        nextOrder = 'desc';
      }
    } else {
      nextField = field;
      nextOrder = 'desc';
    }
    state = state.copyWith(sortField: nextField, sortOrder: nextOrder);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('positionHoldingSortField', nextField);
    await prefs.setString('positionHoldingSortOrder', nextOrder);
  }

  /// 置顶 — 将指定项移到列表顶部并保存排序
  /// 返回结果供页面 toast：'notFound' | 'alreadyTop' | 'pinned' | 'failed'
  Future<String> pinToTop(int assetId) async {
    final items = List<PositionItem>.from(state.items);
    final idx = items.indexWhere((i) => i.assetId == assetId);
    if (idx < 0) return 'notFound';
    if (idx == 0 && (state.sortField.isEmpty || state.sortField == 'sort')) {
      return 'alreadyTop'; // 已在顶部
    }
    final item = items.removeAt(idx);
    items.insert(0, item);
    // 重置排序
    state = state.copyWith(items: items, sortField: '', sortOrder: '');
    // 保存排序到后端
    try {
      final orderMap = <int, int>{};
      final total = items.length;
      for (var i = 0; i < total; i++) {
        if (items[i].assetId > 0) {
          orderMap[items[i].assetId] = total - i;
        }
      }
      if (orderMap.isNotEmpty) {
        await _api.put(
          ApiEndpoints.assetOrder,
          data: {'assetOrders': orderMap},
        );
      }
      return 'pinned';
    } catch (_) {
      return 'failed';
    }
  }

  /// 切换表格展示模式
  void setTableMode(TableShowMode mode) {
    state = state.copyWith(tableMode: mode);
    _saveTableMode(mode);
  }

  /// 删除资产 — 1:1 uni-app deleteAsset: DELETE /asset/api/Asset/{assetId} (V2)
  Future<bool> deleteAsset(int assetId) async {
    try {
      final res = await _api.delete('${ApiEndpoints.assetDeleteV2}/$assetId');
      final code = res.data?['code'] as int?;
      return code == 200;
    } catch (_) {
      return false;
    }
  }

  static int? _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

final positionProvider = StateNotifierProvider<PositionNotifier, PositionState>(
  (ref) {
    return PositionNotifier();
  },
);
