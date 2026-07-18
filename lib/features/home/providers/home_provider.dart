import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/models/symbol.dart';
import '../../../core/enums/enums.dart';
import '../../../core/services/signalr_service.dart';
import '../../../shared/widgets/book_selector_menu.dart';
import '../home_format.dart';

/// Banner 数据 (对齐 uni-app getBanners 返回项)
class HomeBanner {
  final String imageUrl;
  final String themeType; // '0' 浅色 / '1' 深色
  final int sortOrder;

  const HomeBanner({
    required this.imageUrl,
    this.themeType = '',
    this.sortOrder = 0,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        imageUrl: json['imageUrl']?.toString() ?? '',
        themeType: json['themeType']?.toString() ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'imageUrl': imageUrl, 'themeType': themeType, 'sortOrder': sortOrder};
}

/// 账本 (对齐 uni-app homeBookList 项)
class HomeBook {
  final int bookId;
  final String bookName;

  const HomeBook({required this.bookId, required this.bookName});

  factory HomeBook.fromJson(Map<String, dynamic> json) => HomeBook(
        bookId: (json['bookId'] as num?)?.toInt() ?? 0,
        bookName: json['bookName']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'bookId': bookId, 'bookName': bookName};
}

/// 资产汇总 — 1:1 复刻 uni-app assetSummary (全部字符串, '--' 兜底)
class HomeAssetSummary {
  final String totalMarketValue;
  final String totalProfit;
  final String totalProfitRatio;
  final String metalMarketValue;
  final String metalProfit;
  final String metalProfitRatio;
  final String fundMarketValue;
  final String fundProfit;
  final String fundProfitRatio;

  const HomeAssetSummary({
    this.totalMarketValue = '--',
    this.totalProfit = '--',
    this.totalProfitRatio = '--',
    this.metalMarketValue = '--',
    this.metalProfit = '--',
    this.metalProfitRatio = '--',
    this.fundMarketValue = '--',
    this.fundProfit = '--',
    this.fundProfitRatio = '--',
  });

  factory HomeAssetSummary.fromJson(Map<String, dynamic> json) =>
      HomeAssetSummary(
        totalMarketValue: json['totalMarketValue']?.toString() ?? '--',
        totalProfit: json['totalProfit']?.toString() ?? '--',
        totalProfitRatio: json['totalProfitRatio']?.toString() ?? '--',
        metalMarketValue: json['metalMarketValue']?.toString() ?? '--',
        metalProfit: json['metalProfit']?.toString() ?? '--',
        metalProfitRatio: json['metalProfitRatio']?.toString() ?? '--',
        fundMarketValue: json['fundMarketValue']?.toString() ?? '--',
        fundProfit: json['fundProfit']?.toString() ?? '--',
        fundProfitRatio: json['fundProfitRatio']?.toString() ?? '--',
      );

  Map<String, dynamic> toJson() => {
        'totalMarketValue': totalMarketValue,
        'totalProfit': totalProfit,
        'totalProfitRatio': totalProfitRatio,
        'metalMarketValue': metalMarketValue,
        'metalProfit': metalProfit,
        'metalProfitRatio': metalProfitRatio,
        'fundMarketValue': fundMarketValue,
        'fundProfit': fundProfit,
        'fundProfitRatio': fundProfitRatio,
      };
}

/// 首页数据状态
class HomeState {
  static const bookAll = 'all';

  final List<HomeBanner> banners;
  final List<SymbolInfo> topSymbols;
  final List<SymbolInfo> marketList;
  final HomeAssetSummary assetSummary;
  final List<HomeBook> bookList;
  final String selectedBookValue; // 'all' 或 bookId 字符串
  final AssetVisibleState visibleState;
  final String profitDisplayMode; // 'ratio' | 'amount'
  final bool isFundMarketOpen;
  final bool hasFundGroupNotice;
  final String fundGroupNoticeText;
  final List<SymbolInfo> fundList;
  final bool isLoggedIn;
  final bool isLoading;
  final Map<int, bool> marketFlashes; // symbolId → 是否涨 (500ms 闪烁)

  const HomeState({
    this.banners = const [],
    this.topSymbols = const [],
    this.marketList = const [],
    this.assetSummary = const HomeAssetSummary(),
    this.bookList = const [],
    this.selectedBookValue = bookAll,
    this.visibleState = AssetVisibleState.showAll,
    this.profitDisplayMode = 'ratio',
    this.isFundMarketOpen = false,
    this.hasFundGroupNotice = true,
    this.fundGroupNoticeText = '实时热点交流群限时开放中，点击进群讨论',
    this.fundList = const [],
    this.isLoggedIn = false,
    this.isLoading = false,
    this.marketFlashes = const {},
  });

  HomeState copyWith({
    List<HomeBanner>? banners,
    List<SymbolInfo>? topSymbols,
    List<SymbolInfo>? marketList,
    HomeAssetSummary? assetSummary,
    List<HomeBook>? bookList,
    String? selectedBookValue,
    AssetVisibleState? visibleState,
    String? profitDisplayMode,
    bool? isFundMarketOpen,
    bool? hasFundGroupNotice,
    String? fundGroupNoticeText,
    List<SymbolInfo>? fundList,
    bool? isLoggedIn,
    bool? isLoading,
    Map<int, bool>? marketFlashes,
  }) =>
      HomeState(
        banners: banners ?? this.banners,
        topSymbols: topSymbols ?? this.topSymbols,
        marketList: marketList ?? this.marketList,
        assetSummary: assetSummary ?? this.assetSummary,
        bookList: bookList ?? this.bookList,
        selectedBookValue: selectedBookValue ?? this.selectedBookValue,
        visibleState: visibleState ?? this.visibleState,
        profitDisplayMode: profitDisplayMode ?? this.profitDisplayMode,
        isFundMarketOpen: isFundMarketOpen ?? this.isFundMarketOpen,
        hasFundGroupNotice: hasFundGroupNotice ?? this.hasFundGroupNotice,
        fundGroupNoticeText: fundGroupNoticeText ?? this.fundGroupNoticeText,
        fundList: fundList ?? this.fundList,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        marketFlashes: marketFlashes ?? this.marketFlashes,
      );

  /// homeBookOptions: [{value:'all', label:'全部'}, ...账本]
  List<BookOption> get bookOptions => [
        const BookOption(value: bookAll, label: '全部'),
        ...bookList.map((b) => BookOption(
            value: '${b.bookId}',
            label: b.bookName.isEmpty ? '账本${b.bookId}' : b.bookName)),
      ];

  /// currentHomeBookName
  String get currentBookName {
    for (final o in bookOptions) {
      if (o.value == selectedBookValue) return o.label;
    }
    return '全部';
  }
}

/// 首页 Provider — 1:1 复刻 uni-app pages/index/index.vue 数据流
class HomeNotifier extends StateNotifier<HomeState> {
  final ApiClient _api = ApiClient();
  final SignalRService _signalR = SignalRService();
  String? _cacheKey;
  String? _userKey;
  String? _lastRestoredKey;
  final Map<String, double> _marketPrevPrice = {};
  final Map<int, Timer> _marketFlashTimers = {};
  final _cacheTimer = _CacheTimer();

  HomeNotifier() : super(const HomeState()) {
    _init();
  }

  Future<void> _init() async {
    await _restoreCache();
    await restoreProfitDisplayMode(); // 对齐 onShow/onLoad restoreAssetProfitDisplayMode
    await _loadMetals();
    await loadHomePageData();
    _initSignalR();
  }

  // ==================== API 调用 ====================

  /// 获取贵金属行情 (hendlInitHonelist)
  Future<void> _loadMetals() async {
    try {
      final res = await _api.get(ApiEndpoints.marketHotMetals);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        final list = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final metals = list.take(2).map(_normalizeRealtimeItem).toList();
        state = state.copyWith(topSymbols: metals);
        _saveCache();
      }
    } catch (_) {/* 静默处理 */}
  }

  /// 获取首页 Banner (fetchHomeBanners)
  Future<void> _loadBanners() async {
    try {
      final res = await _api.get(ApiEndpoints.banner, queryParameters: {'limit': 10});
      final banners = _parseBannerList(res.data)
          .where((e) => (e['imageUrl']?.toString() ?? '').isNotEmpty)
          .map(HomeBanner.fromJson)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      state = state.copyWith(banners: banners);
      _saveCache();
    } catch (_) {/* 静默处理 */}
  }

  /// parseBannerList: data / items / records / list / rows
  List<Map<String, dynamic>> _parseBannerList(dynamic body) {
    final dynamic data = body is Map ? (body['data'] ?? body) : body;
    List<dynamic>? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final k in ['items', 'records', 'list', 'rows']) {
        if (data[k] is List) {
          raw = data[k] as List;
          break;
        }
      }
    }
    return raw?.whereType<Map<String, dynamic>>().toList() ?? [];
  }

  /// 获取市场指数 (fetchMarketHotIndex)
  Future<void> _loadMarketIndex() async {
    try {
      final res = await _api.get(ApiEndpoints.marketHotIndex);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        final list = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final indices = list
            .asMap()
            .entries
            .map((e) => _normalizeMarketItem(e.value, e.key))
            .toList();
        state = state.copyWith(marketList: indices);
        _initMarketPrevPrice(indices);
        _saveCache();
      }
    } catch (_) {/* 静默处理 */}
  }

  /// 获取基金开盘状态 (fetchFundMarketStatus) — 仅入缓存, 无 UI 使用
  Future<void> _loadFundMarketStatus() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundChangeCount);
      final body = res.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      final open = data is Map && data['isClosed'] == false;
      state = state.copyWith(isFundMarketOpen: open);
    } catch (_) {
      state = state.copyWith(isFundMarketOpen: false);
    }
  }

  /// 加载首页数据 (loadHomePageData)
  Future<void> loadHomePageData() async {
    state = state.copyWith(isLoading: true);
    await _restoreCache();

    await _loadBanners();
    await _loadMarketIndex();
    await _loadFundMarketStatus();

    // 检查登录状态 (uni-app: token && userInfo; Flutter 端未写 userInfo 键, 用 token)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = token != null && token.isNotEmpty;

    if (isLoggedIn) {
      await _restoreBookSelection();
      await _loadBooks();
      await _loadAssetByBook();
    } else {
      _clearLoginAssetData();
      _saveCache();
      await _loadGuestData();
    }

    state = state.copyWith(isLoading: false, isLoggedIn: isLoggedIn);
  }

  /// clearLoginAssetData
  void _clearLoginAssetData() {
    state = state.copyWith(
      assetSummary: const HomeAssetSummary(),
      bookList: const [],
      selectedBookValue: HomeState.bookAll,
      fundList: const [],
    );
    _saveBookSelection();
  }

  /// 登录态: 获取账本资产 (loadHomeAssetByBook)
  Future<void> _loadAssetByBook() async {
    try {
      final bookId = state.selectedBookValue == HomeState.bookAll
          ? null
          : int.tryParse(state.selectedBookValue);
      final res = await _api.get(ApiEndpoints.assetListV2,
          queryParameters: bookId != null ? {'bookId': bookId} : null);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        final list =
            (payload['list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final fundRaw = list.where(_isFundAsset).toList();
        final funds =
            fundRaw.map((e) => _normalizeHomeFundItem(e, 'asst')).toList();
        final summary = _buildAssetSummary(payload, fundRaw);
        state = state.copyWith(fundList: funds, assetSummary: summary);
        _saveCache();
      }
    } catch (_) {/* 静默处理 */}
  }

  /// 未登录: 加载热搜基金 (fetchFundHotList)
  Future<void> _loadGuestData() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundHeatTop);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        var list = data['data'];
        if (list is Map) list = list['all'] ?? list;
        if (list is List) {
          final funds = list
              .cast<Map<String, dynamic>>()
              .take(10)
              .map((e) => _normalizeHomeFundItem(e, 'hot'))
              .toList();
          state = state.copyWith(fundList: funds);
          _saveCache();
        }
      }
    } catch (_) {/* 静默处理 */}
  }

  /// 获取账本列表 (fetchHomeBookList)
  Future<void> _loadBooks() async {
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final data = res.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      }
      final books =
          list.whereType<Map<String, dynamic>>().map(HomeBook.fromJson).toList();
      // 选中账本已不存在 → 重置为全部
      if (state.selectedBookValue != HomeState.bookAll &&
          !books.any((b) => '${b.bookId}' == state.selectedBookValue)) {
        state = state.copyWith(
            bookList: books, selectedBookValue: HomeState.bookAll);
        await _saveBookSelection();
      } else {
        state = state.copyWith(bookList: books);
      }
    } catch (_) {/* 静默处理 */}
  }

  /// 下拉刷新 (onRefresh)
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadMetals();
    await loadHomePageData();
    state = state.copyWith(isLoading: false);
  }

  // ==================== SignalR ====================

  void _initSignalR() {
    Future.delayed(const Duration(seconds: 2), () {
      _signalR.on('OnBatchPriceUpdate', _onBatchPriceUpdate);
      if (!_signalR.isConnected) _signalR.connect();
    });
  }

  /// normalizeSignalRPayload: 兼容 JSON 字符串 / 单条数组 / 二维数组
  List<dynamic> _normalizeSignalRPayload(dynamic payload) {
    dynamic data = payload;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return [];
      }
    }
    if (data is! List) return [];
    if (data.length >= 6 && data[0] is! List) return [data];
    return data;
  }

  /// parseSignalRPriceItem: [symbolId, latestTime, priceType, latestPrice, preClose, chgRate]
  /// chgRate 接口侧已为百分比数值, 直接展示 (不再 ×100)
  Map<String, dynamic> _parseSignalRPriceItem(dynamic item) {
    if (item is List && item.length >= 6) {
      final price = homeToNum(item[3]);
      final preClose = homeToNum(item[4]);
      final chgRate = homeToNum(item[5]);
      return {
        'symbolId': item[0],
        'price': price,
        'preClose': preClose,
        'increase':
            price != null && preClose != null ? price - preClose : null,
        'changeRatio': chgRate,
      };
    }
    return item is Map<String, dynamic> ? item : const <String, dynamic>{};
  }

  void _onBatchPriceUpdate(List<dynamic> args) {
    final payload = args.length == 1 ? args[0] : args;
    final updateList = _normalizeSignalRPayload(payload);
    if (updateList.isEmpty) return;

    final updates = <int, Map<String, dynamic>>{};
    for (final raw in updateList) {
      final item = _parseSignalRPriceItem(raw);
      final id = (item['symbolId'] as num?)?.toInt();
      if (id != null) updates[id] = item;
    }
    if (updates.isEmpty) return;

    // 更新 topSymbols (金银)
    final metals = state.topSymbols.map((s) {
      final u = updates[s.id];
      if (u == null) return s;
      final price = homeToNum(u['price']);
      final preClose = homeToNum(u['preClose']) ?? s.preClose;
      return SymbolInfo(
        id: s.id, code: s.code, name: s.name, type: s.type,
        symbolId: s.symbolId, assetType: s.assetType,
        latestPrice: price ?? s.latestPrice,
        preClose: preClose,
        change: price != null && preClose != null
            ? price - preClose
            : s.change,
        changeRate: homeToNum(u['changeRatio']) ?? s.changeRate,
        updateTime: s.updateTime,
      );
    }).toList();

    // 更新 marketList + 触发涨跌闪烁 (updateMarketListBySymbolId + triggerMarketAnim)
    final flashes = Map<int, bool>.from(state.marketFlashes);
    final markets = state.marketList.map((s) {
      final u = updates[s.id];
      if (u == null) return s;
      final price = homeToNum(u['price']);
      final preClose = homeToNum(u['preClose']) ?? s.preClose;
      final change =
          price != null && preClose != null ? price - preClose : s.change;
      final key = '${s.symbolId ?? s.id}';
      final prev = _marketPrevPrice[key];
      if (price != null && price != prev) {
        _marketPrevPrice[key] = price;
        flashes[s.id] = (homeToNum(u['increase']) ?? (change ?? 0)) > 0;
        _scheduleFlashClear(s.id);
      }
      return SymbolInfo(
        id: s.id, code: s.code, name: s.name, type: s.type,
        symbolId: s.symbolId, assetType: s.assetType,
        latestPrice: price ?? s.latestPrice,
        preClose: preClose,
        change: change,
        changeRate: homeToNum(u['changeRatio']) ?? s.changeRate,
      );
    }).toList();

    state = state.copyWith(
        topSymbols: metals, marketList: markets, marketFlashes: flashes);
    _saveCache();
  }

  /// 500ms 后清除闪烁 (对齐 uni-app setTimeout 500)
  void _scheduleFlashClear(int symbolId) {
    _marketFlashTimers[symbolId]?.cancel();
    _marketFlashTimers[symbolId] =
        Timer(const Duration(milliseconds: 500), () {
      _marketFlashTimers.remove(symbolId);
      if (state.marketFlashes.containsKey(symbolId)) {
        final flashes = Map<int, bool>.from(state.marketFlashes)
          ..remove(symbolId);
        state = state.copyWith(marketFlashes: flashes);
      }
    });
  }

  void _initMarketPrevPrice(List<SymbolInfo> list) {
    _marketPrevPrice.clear();
    for (final item in list) {
      final id = item.symbolId;
      final price = item.latestPrice;
      if (id != null && price != null) _marketPrevPrice['$id'] = price;
    }
  }

  // ==================== 缓存 ====================

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // uni-app 用 userInfo.userId/.../token; Flutter 端未写 userInfo 键, 用 token
    _userKey = (token == null || token.isEmpty)
        ? 'guest'
        : token.substring(0, token.length.clamp(0, 80));
    _cacheKey = 'home_page_cache_v1_$_userKey';
    if (_cacheKey == _lastRestoredKey) return; // 防止重复恢复
    _lastRestoredKey = _cacheKey;

    final raw = prefs.getString(_cacheKey!);
    if (raw == null) return;
    try {
      final cache = jsonDecode(raw) as Map<String, dynamic>;
      final banners = (cache['homeBannerList'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(HomeBanner.fromJson)
              .toList() ??
          [];
      final metals = (cache['topSymbols'] as List?)
              ?.map((e) => SymbolInfo.fromJson(e))
              .toList() ??
          [];
      final markets = (cache['marketList'] as List?)
              ?.map((e) => SymbolInfo.fromJson(e))
              .toList() ??
          [];
      final funds = (cache['fundList'] as List?)
              ?.map((e) => SymbolInfo.fromJson(e))
              .toList() ??
          [];
      final summary = cache['assetSummary'] is Map<String, dynamic>
          ? HomeAssetSummary.fromJson(
              cache['assetSummary'] as Map<String, dynamic>)
          : const HomeAssetSummary();
      final books = (cache['homeBookList'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(HomeBook.fromJson)
              .toList() ??
          [];
      state = state.copyWith(
        assetSummary: summary,
        bookList: books,
        selectedBookValue:
            cache['selectedHomeBookValue']?.toString() ?? state.selectedBookValue,
        isFundMarketOpen: cache['isFundMarketOpen'] == true,
      );
      if (banners.isNotEmpty) state = state.copyWith(banners: banners);
      if (metals.isNotEmpty) state = state.copyWith(topSymbols: metals);
      if (markets.isNotEmpty) {
        state = state.copyWith(marketList: markets);
        _initMarketPrevPrice(markets);
      }
      if (funds.isNotEmpty) state = state.copyWith(fundList: funds);
    } catch (_) {}
  }

  void _saveCache() {
    final key = _cacheKey;
    if (key == null) return;
    final payload = {
      'homeBannerList': state.banners.map((e) => e.toJson()).toList(),
      'topSymbols': state.topSymbols.map(_symbolToJson).toList(),
      'marketList': state.marketList.map(_symbolToJson).toList(),
      'fundList': state.fundList.map(_symbolToJson).toList(),
      'assetSummary': state.assetSummary.toJson(),
      'homeBookList': state.bookList.map((e) => e.toJson()).toList(),
      'selectedHomeBookValue': state.selectedBookValue,
      'isFundMarketOpen': state.isFundMarketOpen,
      'cacheTime': DateTime.now().millisecondsSinceEpoch,
    };
    // 防抖80ms
    _cacheTimer.start(const Duration(milliseconds: 80), () {
      SharedPreferences.getInstance()
          .then((p) => p.setString(key, jsonEncode(payload)));
    });
  }

  // ==================== 账本/收益显示模式持久化 ====================

  String get _bookCacheKey => 'home_asset_book_v1_${_userKey ?? 'guest'}';
  String get _profitDisplayCacheKey =>
      'home_profit_display_v1_${_userKey ?? 'guest'}';

  Future<void> _restoreBookSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_bookCacheKey);
    if (v != null && v.isNotEmpty) {
      state = state.copyWith(selectedBookValue: v);
    }
  }

  Future<void> _saveBookSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookCacheKey, state.selectedBookValue);
  }

  /// restoreAssetProfitDisplayMode
  Future<void> restoreProfitDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_profitDisplayCacheKey);
    if (v == 'amount' || v == 'ratio') {
      state = state.copyWith(profitDisplayMode: v);
    }
  }

  // ==================== 数据转换 (1:1 复刻 uni-app) ====================

  /// normalizeRealtimeItem (REST 初始加载路径)
  /// increaseRatio/changeRatio 接口侧已为百分比数值, 直接使用 (不再 ×100)
  SymbolInfo _normalizeRealtimeItem(Map<String, dynamic> item) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price =
        homeToNum(item['price'] ?? lp['latestPrice'] ?? item['currentPrice']);
    final preClose =
        homeToNum(item['preClose'] ?? item['netValue'] ?? lp['preClose']);
    final hasExplicitIncrease = item['increase'] != null ||
        item['change'] != null ||
        lp['change'] != null ||
        lp['changeRatio'] != null;
    final hasExplicitRatio = item['increaseRatio'] != null ||
        item['changeRatio'] != null ||
        lp['changeRatio'] != null;
    final computedIncrease =
        price != null && preClose != null ? price - preClose : null;
    final increaseFromApi =
        homeToNum(item['increase'] ?? item['change'] ?? lp['change']);
    final increase = hasExplicitIncrease
        ? increaseFromApi
        : (computedIncrease ?? increaseFromApi);
    final computedRatio = increase != null && preClose != null && preClose != 0
        ? increase / preClose * 100
        : null;
    final rawRatio =
        homeToNum(item['increaseRatio'] ?? item['changeRatio'] ?? lp['changeRatio']);
    final ratio = hasExplicitRatio ? rawRatio : (computedRatio ?? rawRatio);
    return SymbolInfo(
      id: (item['symbolId'] as num?)?.toInt() ?? 0,
      symbolId: (item['symbolId'] as num?)?.toInt(),
      code: item['code']?.toString() ?? '',
      name: item['shortName']?.toString() ?? item['name']?.toString() ?? '',
      type: (item['assetType'] as num?)?.toInt() ?? 0,
      assetType: (item['assetType'] as num?)?.toInt(),
      latestPrice: price,
      preClose: preClose,
      change: increase,
      changeRate: ratio,
      updateTime: item['latestTime'] != null
          ? DateTime.tryParse(item['latestTime'].toString())
          : null,
    );
  }

  /// normalizeMarketItem
  SymbolInfo _normalizeMarketItem(Map<String, dynamic> item, int index) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = homeToNum(lp['latestPrice'] ??
        item['latestPrice'] ??
        item['price'] ??
        item['currentPrice']);
    final preClose =
        homeToNum(lp['preClose'] ?? item['preClose'] ?? item['netValue']);
    final rawChange = homeToNum(
        lp['change'] ?? item['increase'] ?? item['changeAmount'] ?? item['change']);
    final change = rawChange ??
        (price != null && preClose != null ? price - preClose : null);
    final rawRate = homeToNum(lp['changeRatio'] ??
        item['increaseRatio'] ??
        item['changeRatio'] ??
        item['chgRate'] ??
        item['riseRatio']);
    final rate = rawRate ??
        (change != null && preClose != null && preClose != 0
            ? change / preClose * 100
            : null);
    return SymbolInfo(
      id: (item['symbolId'] as num?)?.toInt() ?? 0,
      symbolId: (item['symbolId'] as num?)?.toInt(),
      code: item['code']?.toString() ?? '',
      name: item['shortName']?.toString() ??
          item['name']?.toString() ??
          item['symbolName']?.toString() ??
          '热门指数${index + 1}',
      type: (item['assetType'] as num?)?.toInt() ?? 0,
      assetType: (item['assetType'] as num?)?.toInt(),
      latestPrice: price,
      preClose: preClose,
      change: change,
      changeRate: rate,
    );
  }

  /// normalizeHomeFundItem
  /// rate = dayChangeRatio(hot 取 lp.chgRate 原值); change 恒为百分比 (lp.chgRate ?? lp.changeRatio)
  SymbolInfo _normalizeHomeFundItem(Map<String, dynamic> item, String type) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = homeToNum(lp['latestPrice']) ?? 0;
    final dayChangeRatio = type == 'hot'
        ? homeToNum(lp['chgRate'] ?? lp['changeRatio'])
        : (homeToNum(item['dayChangeRatio'] ?? lp['changeRatio']) ?? 0);
    final changePercent = homeToNum(lp['chgRate'] ?? lp['changeRatio']);
    return SymbolInfo(
      id: (item['symbolId'] as num?)?.toInt() ?? 0,
      symbolId: (item['symbolId'] as num?)?.toInt(),
      assetType: (item['assetType'] as num?)?.toInt(),
      assetId: (item['assetId'] as num?)?.toInt(),
      code: item['symbolCode']?.toString() ?? item['code']?.toString() ?? '',
      name: item['shortName']?.toString() ?? item['name']?.toString() ?? '',
      type: 3, // 基金
      typeName: item['fundTypeName']?.toString(),
      latestPrice: price,
      change: changePercent,
      changeRate: dayChangeRatio,
    );
  }

  /// buildAssetSummaryFromFundList — 1:1 复刻
  /// fundMarketValue = Σ marketValue; ratio = data.totalDayChangeRatio ?? 加权平均
  /// (接口侧已为百分比数值, 不再 ×100)
  HomeAssetSummary _buildAssetSummary(
      Map<String, dynamic> data, List<Map<String, dynamic>> fundAssets) {
    final fundMarketValue = fundAssets.fold<double>(
        0, (s, item) => s + (homeToNum(item['marketValue']) ?? 0));
    final totalDayProfit =
        data['totalDayProfit'] != null ? homeToNum(data['totalDayProfit']) : null;
    final weighted = fundMarketValue > 0
        ? fundAssets.fold<double>(
                0,
                (s, item) =>
                    s +
                    (homeToNum(item['dayChangeRatio']) ?? 0) *
                        (homeToNum(item['marketValue']) ?? 0)) /
            fundMarketValue
        : 0.0;
    final totalDayChangeRatio = data['totalDayChangeRatio'] != null
        ? (homeToNum(data['totalDayChangeRatio']) ?? 0.0)
        : weighted;
    final mvText = homeFmtDecimal(fundMarketValue, 2, '--');
    final profitText = homeFmtDecimal(totalDayProfit, 2, '--');
    final ratioText = homeFmtSignedPercent(totalDayChangeRatio, 2);
    return HomeAssetSummary(
      totalMarketValue: mvText,
      totalProfit: profitText,
      totalProfitRatio: ratioText,
      // 首页不展示金属持仓明细, 与 uni-app 一致恒为 '--'
      fundMarketValue: mvText,
      fundProfit: profitText,
      fundProfitRatio: ratioText,
    );
  }

  bool _isFundAsset(Map<String, dynamic> item) => item['assetType'] == 3;

  Map<String, dynamic> _symbolToJson(SymbolInfo s) => {
        'id': s.id,
        'symbolId': s.symbolId,
        'assetType': s.assetType,
        'assetId': s.assetId,
        'code': s.code,
        'name': s.name,
        'type': s.type,
        'typeName': s.typeName,
        'latestPrice': s.latestPrice,
        'preClose': s.preClose,
        'change': s.change,
        'changeRate': s.changeRate,
      };

  // ==================== 交互 ====================

  void toggleAssetVisible() =>
      state = state.copyWith(visibleState: state.visibleState.next());

  /// handleHomeBookSelect: 选中账本 → 持久化 → 重新加载资产
  Future<void> selectBook(String value) async {
    if (state.selectedBookValue == value) return;
    state = state.copyWith(selectedBookValue: value);
    await _saveBookSelection();
    await _loadAssetByBook();
  }

  /// toggleAssetProfitDisplay: 收益标签 比例/金额 切换 + 持久化
  Future<void> toggleProfitDisplayMode() async {
    final mode = state.profitDisplayMode == 'ratio' ? 'amount' : 'ratio';
    state = state.copyWith(profitDisplayMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profitDisplayCacheKey, mode);
  }

  void dismissNotice() => state = state.copyWith(hasFundGroupNotice: false);

  @override
  void dispose() {
    for (final t in _marketFlashTimers.values) {
      t.cancel();
    }
    _marketFlashTimers.clear();
    _cacheTimer.cancel();
    super.dispose();
  }
}

/// 防抖 Timer 包装 (延迟写入缓存)
class _CacheTimer {
  Timer? _timer;
  void cancel() => _timer?.cancel();
  void start(Duration d, VoidCallback cb) {
    cancel();
    _timer = Timer(d, cb);
  }
}

/// HomeState Provider
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier();
});
