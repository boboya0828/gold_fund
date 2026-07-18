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
      isLatestNav: json['isLatestNav'] == true,
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
    );
  }

  /// 最新涨跌幅 (来自 latestPrice.chgRate)
  double get latestChgRate {
    if (latestPrice?.chgRate != null) {
      return latestPrice!.chgRate!;
    }
    return dayChangeRatio;
  }

  /// 第一个关联指标
  IndicatorItem? get firstIndicator {
    if (indicatorList != null && indicatorList!.isNotEmpty) {
      return indicatorList![0];
    }
    return latestPrice?.indicatorList?.isNotEmpty == true
        ? latestPrice!.indicatorList![0]
        : null;
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
  final List<IndicatorItem>? indicatorList;

  const LatestPriceInfo({
    this.latestPrice,
    this.preClose,
    this.chgRate,
    this.priceType,
    this.latestTime,
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

/// 持仓页状态
class PositionState {
  final List<BookItem> books;
  final int tabIndex; // 0=全部
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
  final TableShowMode tableMode;
  final String sortField;
  final String sortOrder; // 'asc' or 'desc'
  final bool isLoggedIn;
  final String? errorMessage;

  const PositionState({
    this.books = const [],
    this.tabIndex = 1, // 1:1 uni-app taberIndex ref(1)：默认选第一个账本(非"全部")；无账本时 loadData 越界回退到 0

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
    this.tableMode = TableShowMode.normal,
    this.sortField = 'sort',
    this.sortOrder = 'desc',
    this.isLoggedIn = false,
    this.errorMessage,
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
    TableShowMode? tableMode,
    String? sortField,
    String? sortOrder,
    bool? isLoggedIn,
    String? errorMessage,
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
    tableMode: tableMode ?? this.tableMode,
    sortField: sortField ?? this.sortField,
    sortOrder: sortOrder ?? this.sortOrder,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    errorMessage: errorMessage,
  );

  /// 账本名称列表
  List<String> get bookNames => ['全部', ...books.map((b) => b.bookName)];

  /// 当前选中的 bookId (null=全部)
  int? get currentBookId => tabIndex == 0
      ? null
      : books.isNotEmpty && tabIndex - 1 < books.length
      ? books[tabIndex - 1].bookId
      : null;

  // ---- 隐私级别派生 (1:1 uni-app hideXxx computed) ----
  bool get hideHoldAmount => assetVisible >= AssetVisibleLevel.hideHoldAmount;
  bool get hideIncomeAmount =>
      assetVisible >= AssetVisibleLevel.hideIncomeAmount;
  bool get hideIncomeRate => assetVisible >= AssetVisibleLevel.hideIncomeRate;
  bool get hideFundName => assetVisible >= AssetVisibleLevel.hideFundName;

  /// 表头日期标签 (MM-dd)：优先接口 curTradeDate，否则最近一个工作日
  /// (uni-app 用 chinese-days 跳过法定节假日，这里仅跳过周末 —— 见迁移报告)
  String get headerDateLabel {
    final d = _parseDate(curTradeDate) ?? _lastWeekday(DateTime.now());
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

  /// 排序后的列表
  List<PositionItem> get sortedItems {
    final result = List<PositionItem>.from(items);
    if (sortField == 'sort' || sortField.isEmpty) return result;
    result.sort((a, b) {
      final av = _getSortValue(a, sortField);
      final bv = _getSortValue(b, sortField);
      return sortOrder == 'asc' ? av.compareTo(bv) : bv.compareTo(av);
    });
    return result;
  }

  double _getSortValue(PositionItem item, String field) {
    switch (field) {
      case 'dayProfit':
        return item.dayProfit;
      case 'increaseRatio':
        // 1:1 uni-app getSortValue: 普通模式按关联板块涨幅，简洁/极简按最新涨幅
        if (tableMode == TableShowMode.normal) {
          return item.firstIndicator?.changeRatio ?? 0;
        }
        return item.latestChgRate;
      case 'latestPrice.chgRate':
        return item.latestChgRate;
      case 'holdProfit':
        return item.holdProfit;
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

/// 持仓页 Provider — 1:1 复刻 uni-app pages/positionv1/index.uvue 数据流
class PositionNotifier extends StateNotifier<PositionState> {
  final ApiClient _api = ApiClient();

  PositionNotifier() : super(const PositionState()) {
    _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getInt('tableShowMode') ?? 0;
    // 1:1 uni-app positionShowProfitRatio 缓存
    final showRatio = prefs.getBool('positionShowProfitRatio') ?? false;
    state = state.copyWith(
      tableMode: TableShowMode.values[mode.clamp(0, 2)],
      showProfitRatio: showRatio,
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

  /// 获取资产列表
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

      state = state.copyWith(
        items: items,
        totalMarketValue: totalMarketValue,
        totalDayProfit: totalDayProfit,
        totalDayChangeRatio: totalDayChangeRatio,
        curTradeDate: curTradeDate,
      );
    } catch (_) {}
  }

  /// 加载全部数据 (queryPositionPaging)
  Future<void> loadData({bool showRefreshTip = false}) async {
    state = state.copyWith(isLoading: true);

    // 检查登录
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = token != null && token.isNotEmpty;
    if (!isLoggedIn) {
      state = state.copyWith(isLoading: false, isLoggedIn: false, items: []);
      return;
    }

    try {
      final books = await _fetchBooks();
      final currentBook = state.currentBookId;

      // 确保 tabIndex 不越界
      var tabIdx = state.tabIndex;
      if (tabIdx > books.length) tabIdx = 0;

      state = state.copyWith(books: books, tabIndex: tabIdx, isLoggedIn: true);
      await _fetchAssets(currentBook);

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

  /// 下拉刷新
  Future<void> refresh() => loadData(showRefreshTip: true);

  /// 切换账本 — 1:1 uni-app watch(taberIndex)：只重新拉取资产列表，不重拉账本
  void selectTab(int index) {
    if (index == state.tabIndex) return;
    state = state.copyWith(tabIndex: index);
    _fetchAssets(state.currentBookId);
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

  /// 切换排序 — 1:1 复刻 uni-app toggleMetalSort: desc → asc → cleared → desc
  void toggleSort(String field) {
    if (state.sortField == field) {
      if (state.sortOrder == 'desc') {
        state = state.copyWith(sortOrder: 'asc');
      } else if (state.sortOrder == 'asc') {
        state = state.copyWith(sortField: '', sortOrder: '');
      } else {
        state = state.copyWith(sortOrder: 'desc');
      }
    } else {
      state = state.copyWith(sortField: field, sortOrder: 'desc');
    }
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
