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

/// 资产可见模式: 0=全部可见, 1=隐藏金额, 2=隐藏盈亏
enum AssetVisibleMode { showAll, hideAmount, hideProfit }

extension AssetVisibleModeExt on AssetVisibleMode {
  AssetVisibleMode next() {
    switch (this) {
      case AssetVisibleMode.showAll:
        return AssetVisibleMode.hideAmount;
      case AssetVisibleMode.hideAmount:
        return AssetVisibleMode.hideProfit;
      case AssetVisibleMode.hideProfit:
        return AssetVisibleMode.showAll;
    }
  }
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
  final AssetVisibleMode visibleMode;
  final bool isLoading;
  final String? refreshTime;
  final bool showRatioTip;
  final TableShowMode tableMode;
  final String sortField;
  final String sortOrder; // 'asc' or 'desc'
  final bool isLoggedIn;
  final String? errorMessage;

  const PositionState({
    this.books = const [],
    this.tabIndex = 0,
    this.items = const [],
    this.totalMarketValue = 0,
    this.totalDayProfit = 0,
    this.totalDayChangeRatio = 0,
    this.visibleMode = AssetVisibleMode.showAll,
    this.isLoading = false,
    this.refreshTime,
    this.showRatioTip = false,
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
    AssetVisibleMode? visibleMode,
    bool? isLoading,
    String? refreshTime,
    bool? showRatioTip,
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
    visibleMode: visibleMode ?? this.visibleMode,
    isLoading: isLoading ?? this.isLoading,
    refreshTime: refreshTime ?? this.refreshTime,
    showRatioTip: showRatioTip ?? this.showRatioTip,
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

  /// 排序后的列表
  List<PositionItem> get sortedItems {
    final result = List<PositionItem>.from(items);
    if (sortField == 'sort') return result;
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
        return item.firstIndicator?.changeRatio ?? 0;
      case 'latestPrice.chgRate':
        return item.latestChgRate;
      case 'holdProfit':
        return item.holdProfit;
      default:
        return 0;
    }
  }

  /// 是否基金市场休市
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
    _restoreTableMode();
  }

  Future<void> _restoreTableMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getInt('tableShowMode') ?? 0;
    state = state.copyWith(tableMode: TableShowMode.values[mode.clamp(0, 2)]);
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
      final totalDayChangeRatio =
          (_toNum(payload['totalDayChangeRatio']) ?? 0) * 100;

      state = state.copyWith(
        items: items,
        totalMarketValue: totalMarketValue,
        totalDayProfit: totalDayProfit,
        totalDayChangeRatio: totalDayChangeRatio,
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
        state = state.copyWith(refreshTime: '$h:$m:$s', showRatioTip: true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) state = state.copyWith(showRatioTip: false);
        });
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 下拉刷新
  Future<void> refresh() => loadData(showRefreshTip: true);

  /// 切换账本
  void selectTab(int index) {
    if (index == state.tabIndex) return;
    state = state.copyWith(tabIndex: index);
    loadData();
  }

  // ==================== 交互 ====================

  /// 切换资产可见性
  void toggleVisible() {
    state = state.copyWith(visibleMode: state.visibleMode.next());
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
  Future<void> pinToTop(int assetId) async {
    final items = List<PositionItem>.from(state.items);
    final idx = items.indexWhere((i) => i.assetId == assetId);
    if (idx < 0) return;
    if (idx == 0 && state.sortField.isEmpty) return; // 已在顶部
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
    } catch (_) {
      /* 静默处理 */
    }
  }

  /// 切换表格展示模式
  void setTableMode(TableShowMode mode) {
    state = state.copyWith(tableMode: mode);
    _saveTableMode(mode);
  }

  /// 删除资产
  Future<bool> deleteAsset(int assetId) async {
    try {
      final res = await _api.delete(
        '${ApiEndpoints.assetDetailDelete}/$assetId',
      );
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
