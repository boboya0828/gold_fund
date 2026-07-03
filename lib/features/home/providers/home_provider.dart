import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/models/symbol.dart';
import '../../../core/models/asset.dart';
import '../../../core/models/book.dart';
import '../../../core/enums/enums.dart';
import '../../../core/services/signalr_service.dart';

/// 首页数据状态
class HomeState {
  final List<SymbolInfo> topSymbols;
  final List<SymbolInfo> marketList;
  final AssetOverview? assetOverview;
  final String? selectedBookName;
  final List<String> bookNames;
  final AssetVisibleState visibleState;
  final bool isLoading;
  final bool hasFundGroupNotice;
  final String? fundGroupNoticeText;
  final List<SymbolInfo> fundList;
  final bool hasAsset;
  final bool isLoggedIn;

  const HomeState({
    this.topSymbols = const [],
    this.marketList = const [],
    this.assetOverview,
    this.selectedBookName,
    this.bookNames = const ['全部'],
    this.visibleState = AssetVisibleState.showAll,
    this.isLoading = false,
    this.hasFundGroupNotice = true,
    this.fundGroupNoticeText = '欢迎加入养基助手交流群，获取更多基金投资知识',
    this.fundList = const [],
    this.hasAsset = false,
    this.isLoggedIn = false,
  });

  HomeState copyWith({
    List<SymbolInfo>? topSymbols, List<SymbolInfo>? marketList,
    AssetOverview? assetOverview, String? selectedBookName,
    List<String>? bookNames, AssetVisibleState? visibleState,
    bool? isLoading, bool? hasFundGroupNotice,
    String? fundGroupNoticeText, List<SymbolInfo>? fundList,
    bool? hasAsset, bool? isLoggedIn,
  }) => HomeState(
    topSymbols: topSymbols ?? this.topSymbols,
    marketList: marketList ?? this.marketList,
    assetOverview: assetOverview ?? this.assetOverview,
    selectedBookName: selectedBookName ?? this.selectedBookName,
    bookNames: bookNames ?? this.bookNames,
    visibleState: visibleState ?? this.visibleState,
    isLoading: isLoading ?? this.isLoading,
    hasFundGroupNotice: hasFundGroupNotice ?? this.hasFundGroupNotice,
    fundGroupNoticeText: fundGroupNoticeText ?? this.fundGroupNoticeText,
    fundList: fundList ?? this.fundList,
    hasAsset: hasAsset ?? this.hasAsset,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
  );
}

/// 首页 Provider — 1:1 复刻 uni-app pages/index/index.vue 数据流
class HomeNotifier extends StateNotifier<HomeState> {
  final ApiClient _api = ApiClient();
  final SignalRService _signalR = SignalRService();
  String? _cacheKey;

  HomeNotifier() : super(const HomeState()) {
    _init();
  }

  Future<void> _init() async {
    await _restoreCache();
    await _loadMetals();
    await loadHomePageData(); // 加载市场指数 + 基金数据 (与 uni-app onShow 对齐)
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
    } catch (e) { /* 静默处理 */ }
  }

  /// 获取市场指数 (fetchMarketHotIndex)
  Future<void> _loadMarketIndex() async {
    try {
      final res = await _api.get(ApiEndpoints.marketHotIndex);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        final list = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final indices = list.asMap().entries.map((e) => _normalizeMarketItem(e.value, e.key)).toList();
        state = state.copyWith(marketList: indices);
        _saveCache();
      }
    } catch (e) { /* 静默处理 */ }
  }

  /// 加载首页数据 (loadHomePageData)
  Future<void> loadHomePageData() async {
    state = state.copyWith(isLoading: true);
    await _restoreCache();

    // 检查登录状态
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = token != null && token.isNotEmpty;

    await Future.wait([
      _loadMarketIndex(),
      if (isLoggedIn) _loadAssetData() else _loadGuestData(),
    ]);

    state = state.copyWith(isLoading: false, isLoggedIn: isLoggedIn);
  }

  /// 登录态: 加载账户和资产
  Future<void> _loadAssetData() async {
    try {
      // 获取账本
      final books = await _loadBooks();
      // 获取资产
      final bookId = await _restoreBookSelection();
      final res = await _api.get(ApiEndpoints.assetListV2,
        queryParameters: bookId != null ? {'bookId': bookId} : null);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        final list = (payload['list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final funds = list.where(_isFundAsset).map((e) => _normalizeHomeFundItem(e, 'asst')).toList();
        final summary = _buildAssetSummary(payload, funds);
        state = state.copyWith(
          fundList: funds, assetOverview: summary,
          bookNames: books, selectedBookName: _resolveBookName(books, bookId),
          hasAsset: funds.isNotEmpty,
        );
        _saveCache();
      }
    } catch (e) { /* 静默处理 */ }
  }

  /// 未登录: 加载热搜基金
  Future<void> _loadGuestData() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundHeatTop);
      final data = res.data;
      if (data != null && data['code'] == 200) {
        var list = data['data'];
        if (list is Map) list = list['all'] ?? list;
        if (list is List) {
          final funds = list.cast<Map<String, dynamic>>()
              .take(10).map((e) => _normalizeHomeFundItem(e, 'hot')).toList();
          state = state.copyWith(fundList: funds, hasAsset: false);
          _saveCache();
        }
      }
    } catch (e) { /* 静默处理 */ }
  }

  Future<List<String>> _loadBooks() async {
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final data = res.data;
      List<dynamic> list = [];
      if (data != null) {
        if (data is List) { list = data; }
        else if (data['data'] is List) { list = data['data']; }
      }
      return ['全部', ...list.map((b) => b['bookName'] ?? b['name'] ?? '')];
    } catch (_) { return ['全部']; }
  }

  /// 下拉刷新
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([_loadMetals(), loadHomePageData()]);
    state = state.copyWith(isLoading: false);
  }

  // ==================== SignalR ====================

  void _initSignalR() {
    Future.delayed(const Duration(seconds: 2), () {
      _signalR.on('OnBatchPriceUpdate', _onBatchPriceUpdate);
      if (!_signalR.isConnected) _signalR.connect();
    });
  }

  void _onBatchPriceUpdate(List<dynamic> args) {
    // args 格式: [[symbolId, time, type, price, preClose, chgRate], ...]
    final updates = <int, Map<String, dynamic>>{};
    for (final item in args) {
      if (item is List && item.length >= 6) {
        final id = item[0] as int;
        updates[id] = {
          'symbolId': id,
          'latestPrice': (item[3] as num).toDouble(),
          'preClose': (item[4] as num).toDouble(),
          'changeRate': (item[5] as num).toDouble() * 100,
        };
      }
    }
    if (updates.isEmpty) return;
    // 更新 topSymbols
    final metals = state.topSymbols.map((s) {
      final u = updates[s.id];
      if (u == null) return s;
      return SymbolInfo(
        id: s.id, code: s.code, name: s.name, type: s.type,
        latestPrice: u['latestPrice'] as double?,
        preClose: u['preClose'] as double?,
        change: (u['latestPrice'] as double?) != null && (u['preClose'] as double?) != null
            ? (u['latestPrice'] as double) - (u['preClose'] as double) : s.change,
        changeRate: u['changeRate'] as double?,
      );
    }).toList();
    // 更新 marketList
    final markets = state.marketList.map((s) {
      final u = updates[s.id];
      if (u == null) return s;
      return SymbolInfo(
        id: s.id, code: s.code, name: s.name, type: s.type,
        latestPrice: u['latestPrice'] as double?,
        changeRate: u['changeRate'] as double?,
      );
    }).toList();
    state = state.copyWith(topSymbols: metals, marketList: markets);
    _saveCache();
  }

  // ==================== 缓存 ====================

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userKey = (token ?? 'guest').substring(0, (token ?? 'guest').length.clamp(0, 80));
    _cacheKey = 'home_page_cache_v1_$userKey';
    if (_cacheKey == _lastRestoredKey) return; // 防止重复恢复
    _lastRestoredKey = _cacheKey;

    final raw = prefs.getString(_cacheKey!);
    if (raw == null) return;
    try {
      final cache = jsonDecode(raw) as Map<String, dynamic>;
      final metals = (cache['topSymbols'] as List?)
          ?.map((e) => SymbolInfo.fromJson(e)).toList() ?? [];
      final markets = (cache['marketList'] as List?)
          ?.map((e) => SymbolInfo.fromJson(e)).toList() ?? [];
      final funds = (cache['fundList'] as List?)
          ?.map((e) => SymbolInfo.fromJson(e)).toList() ?? [];
      final summary = cache['assetSummary'] != null
          ? AssetOverview.fromJson(cache['assetSummary'])
          : null;
      state = state.copyWith(
        topSymbols: metals, marketList: markets,
        fundList: funds, assetOverview: summary,
        hasAsset: summary != null && (summary.totalAssets > 0 || funds.isNotEmpty),
      );
    } catch (_) {}
  }

  String? _lastRestoredKey;

  void _saveCache() {
    if (_cacheKey == null) return;
    final payload = {
      'topSymbols': state.topSymbols.map((e) => _symbolToJson(e)).toList(),
      'marketList': state.marketList.map((e) => _symbolToJson(e)).toList(),
      'fundList': state.fundList.map((e) => _symbolToJson(e)).toList(),
      if (state.assetOverview != null) 'assetSummary': _overviewToJson(state.assetOverview!),
      'cacheTime': DateTime.now().millisecondsSinceEpoch,
    };
    // 防抖80ms
    _cacheTimer.start(const Duration(milliseconds: 80), () {
      SharedPreferences.getInstance().then((p) => p.setString(_cacheKey!, jsonEncode(payload)));
    });
  }

  final _cacheTimer = _CacheTimer();

  Future<int?> _restoreBookSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('home_asset_book_v1_${_cacheKey?.split('_').last ?? ''}');
    if (v == 'all' || v == null || v.isEmpty) return null;
    return int.tryParse(v);
  }

  String _resolveBookName(List<String> books, int? bookId) {
    // 简化: 如果有账本就选第一个非"全部"
    return bookId != null && books.length > 1 ? books[1] : '全部';
  }

  // ==================== 数据转换 (1:1 复刻 uni-app) ====================

  /// normalizeRealtimeItem
  SymbolInfo _normalizeRealtimeItem(Map<String, dynamic> item) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = _toNum(item['price'] ?? lp['latestPrice'] ?? item['currentPrice']);
    final preClose = _toNum(item['preClose'] ?? item['netValue'] ?? lp['preClose']);
    final change = _toNum(item['change'] ?? (price != null && preClose != null ? price - preClose : null));
    // chgRate 是小数(0.0044=0.44%), 统一 ×100 转百分比
    final rawRate = _toNum(item['changeRatio'] ?? lp['changeRatio'] ?? lp['chgRate']);
    final changeRate = rawRate != null ? rawRate * 100
        : (preClose != null && preClose != 0 && change != null ? change / preClose * 100 : null);
    return SymbolInfo(
      id: item['symbolId'] as int? ?? 0,
      code: item['code'] as String? ?? '',
      name: item['shortName'] as String? ?? item['name'] as String? ?? '',
      type: item['assetType'] as int? ?? 0,
      latestPrice: price,
      preClose: preClose,
      change: change,
      changeRate: changeRate,
      updateTime: item['latestTime'] != null ? DateTime.tryParse(item['latestTime'].toString()) : null,
    );
  }

  /// normalizeMarketItem
  SymbolInfo _normalizeMarketItem(Map<String, dynamic> item, int index) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = _toNum(lp['latestPrice'] ?? item['latestPrice'] ?? item['price'] ?? item['currentPrice']);
    final preClose = _toNum(lp['preClose'] ?? item['preClose'] ?? item['netValue']);
    final change = _toNum(lp['change'] ?? (price != null && preClose != null ? price - preClose : null));
    // chgRate/changeRatio 是小数, ×100 转百分比; 计算值已乘过100
    final raw = _toNum(lp['changeRatio'] ?? lp['chgRate']);
    final rate = raw != null ? raw * 100
        : (change != null && preClose != null && preClose != 0 ? change / preClose * 100 : null);
    return SymbolInfo(
      id: item['symbolId'] as int? ?? 0,
      code: item['code'] as String? ?? '',
      name: item['shortName'] as String? ?? item['name'] as String? ?? '热门指数${index + 1}',
      type: item['assetType'] as int? ?? 0,
      latestPrice: price,
      preClose: preClose,
      change: change,
      changeRate: rate,
    );
  }

  /// normalizeHomeFundItem
  SymbolInfo _normalizeHomeFundItem(Map<String, dynamic> item, String type) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = _toNum(lp['latestPrice']) ?? 0;
    final dayChangeRatio = type == 'hot'
        ? _toNum(lp['chgRate'] ?? lp['changeRatio'])
        : _toNum(item['dayChangeRatio'] ?? lp['changeRatio']);
    final change = _toNum(item['dayProfit'] ?? lp['change']);
    return SymbolInfo(
      id: item['symbolId'] as int? ?? 0,
      code: item['symbolCode'] as String? ?? item['code'] as String? ?? '',
      name: item['shortName'] as String? ?? item['name'] as String? ?? '',
      type: 3, // 基金
      typeName: item['fundTypeName'] as String?,
      latestPrice: price,
      change: change,
      changeRate: dayChangeRatio,
    );
  }

  /// buildAssetSummaryFromFundList
  AssetOverview _buildAssetSummary(Map<String, dynamic> data, List<SymbolInfo> funds) {
    final fundMarketValue = funds.fold<double>(0, (s, f) => s + (f.latestPrice ?? 0));
    final fundProfit = funds.fold<double>(0, (s, f) => s + (f.change ?? 0));
    final totalDayChangeRatio = _toNum(data['totalDayChangeRatio']) != null
        ? _toNum(data['totalDayChangeRatio'])! * 100
        : (fundMarketValue > 0
            ? funds.fold<double>(0, (s, f) => s + (f.changeRate ?? 0) * (f.latestPrice ?? 0)) / fundMarketValue
            : 0.0);
    final ratio = totalDayChangeRatio ?? 0;
    return AssetOverview(
      totalAssets: fundMarketValue,
      totalProfit: fundProfit,
      totalProfitRate: ratio,
      dayProfit: fundProfit,
      dayProfitRate: ratio,
      metalAssets: 0, metalProfit: 0,
      fundAssets: fundMarketValue, fundProfit: fundProfit,
    );
  }

  bool _isFundAsset(Map<String, dynamic> item) => item['assetType'] == 3;

  double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Map<String, dynamic> _symbolToJson(SymbolInfo s) => {
    'id': s.id, 'code': s.code, 'name': s.name, 'type': s.type,
    'latestPrice': s.latestPrice, 'preClose': s.preClose,
    'change': s.change, 'changeRate': s.changeRate,
  };

  Map<String, dynamic> _overviewToJson(AssetOverview o) => {
    'totalAssets': o.totalAssets, 'totalProfit': o.totalProfit,
    'totalProfitRate': o.totalProfitRate, 'dayProfit': o.dayProfit,
    'dayProfitRate': o.dayProfitRate,
  };

  // ==================== 交互 ====================

  void toggleAssetVisible() => state = state.copyWith(visibleState: state.visibleState.next());

  void selectBook(String name) => state = state.copyWith(selectedBookName: name);

  void dismissNotice() => state = state.copyWith(hasFundGroupNotice: false);
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
