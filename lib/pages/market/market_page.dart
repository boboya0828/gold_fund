import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import 'widgets/distribution_panel.dart';
import 'widgets/market_header.dart';
import 'widgets/market_models.dart';
import 'widgets/quote_strip.dart';
import 'widgets/rank_panels.dart';

/// 行情页面 - 1:1 复刻 zdj-v1 pages/market/index.vue
///
/// 区块：头部(渐变背景+标题+搜索) → 热门指数横滑卡片 → 今日涨跌分布 →
///       板块收益排行(前6) → 基金自选榜单(前6)；下拉刷新重载全部接口。
/// 接口：hotIndex / fundSectorRanking / FundPickTop / FundChangeCount。
/// 注意：zdj-v1 的该页面没有接入 SignalR 实时推送（无 signalr import）。
class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});
  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage> {
  final ApiClient _api = ApiClient();

  List<QuoteCardData> _quoteCards = [];
  List<DistItem> _distData = [];
  List<SectorRankItem> _sectorRanks = [];
  List<FundRankItemData> _fundRanks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchHotIndex(),
      _fetchSectorRanks(),
      _fetchFundRanks(),
      _fetchChangeCount(),
    ]);
    if (mounted) setState(() {});
  }

  // ==================== API calls ====================

  Future<void> _fetchHotIndex() async {
    try {
      final res = await _api.get(ApiEndpoints.marketHotIndex);
      final data = res.data;
      if (data?['code'] == 200 && data!['data'] is List) {
        _quoteCards = (data['data'] as List)
            .cast<Map<String, dynamic>>()
            .asMap()
            .entries
            .map((e) => _normQuote(e.value, e.key))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchSectorRanks() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundSectorRanking);
      final data = res.data;
      if (data?['code'] == 200 && data!['data'] is List) {
        _sectorRanks = (data['data'] as List)
            .cast<Map<String, dynamic>>()
            .take(6)
            .toList()
            .asMap()
            .entries
            .map((e) => _normSector(e.value, e.key))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchFundRanks() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundPickTop);
      final data = res.data;
      if (data?['code'] == 200) {
        // 接口返回 Record<string, SymbolSimpleDto[]>，取第一个 key 的数组（1:1 源码）
        final payload = data!['data'];
        List<dynamic> list = const [];
        if (payload is List) {
          list = payload;
        } else if (payload is Map && payload.isNotEmpty) {
          final first = payload.values.first;
          if (first is List) list = first;
        }
        _fundRanks = list
            .cast<Map<String, dynamic>>()
            .take(6)
            .toList()
            .asMap()
            .entries
            .map((e) => _normFund(e.value, e.key))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchChangeCount() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundChangeCount);
      final data = res.data;
      final cc = data?['data']?['changeCount'] ?? data?['changeCount'];
      if (cc is List) {
        final list = cc.cast<Map<String, dynamic>>();
        final mx = list.fold<int>(1, (m, e) => _n(e['count']) > m ? _n(e['count']) : m);
        _distData = list.map((e) {
          final c = _n(e['count']);
          final n = (e['name'] as String?) ?? '';
          // 判断涨跌：负值区间绿色，其他红色；'0' 为平盘（1:1 源码，含 '≤' 前缀）
          String t = 'up';
          if (n.startsWith('-') || n.startsWith('<') || n.startsWith('≤') || n.startsWith('~-')) t = 'down';
          if (n == '0') t = 'flat';
          // 最大高度 146rpx(=73)，min-height 4rpx(=2)
          final h = mx > 0 ? ((c / mx) * 73).round().clamp(2, 73) : 2;
          return DistItem(label: n, value: c, height: h, type: t);
        }).toList();
      }
    } catch (_) {}
  }

  // ==================== Normalization (1:1 zdj-v1 script) ====================

  QuoteCardData _normQuote(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? const {};
    final price = _ndn(lp['latestPrice'] ?? item['latestPrice'] ?? item['price'] ?? item['currentPrice']);
    final preClose = _ndn(lp['preClose'] ?? item['preClose'] ?? item['netValue']);
    var change = _ndn(lp['change'] ?? item['increase'] ?? item['changeAmount'] ?? item['change']);
    change ??= (price != null && preClose != null) ? price - preClose : null;
    var rate = _ndn(lp['changeRatio'] ?? item['increaseRatio'] ?? item['changeRatio'] ?? item['chgRate'] ?? item['riseRatio']);
    if (rate == null && change != null && preClose != null && preClose != 0) {
      rate = change / preClose * 100;
    }
    final trendValue = rate ?? change ?? 0;
    return QuoteCardData(
      symbolId: '${item['symbolId'] ?? ''}',
      name: _firstStr(item, const ['shortName', 'name', 'symbolName'], '热门指数${i + 1}'),
      price: _fmtPrice(price),
      change: _fmtSigned(change),
      rate: _fmtRate(rate),
      trend: trendValue < 0 ? 'down' : 'up',
    );
  }

  SectorRankItem _normSector(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? const {};
    final rate = _ndn(lp['chgRate']) ?? 0; // 接口返回值本身已是百分数，直接 toFixed(2)%
    return SectorRankItem(
      rank: i + 1,
      name: _firstStr(item, const ['shortName', 'name', 'symbolName'], '板块${i + 1}'),
      rate: _fmtRate(rate),
      symbolId: '${item['symbolId'] ?? ''}',
      trend: rate < 0 ? 'down' : 'up',
    );
  }

  FundRankItemData _normFund(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? const {};
    final preClose = _ndn(lp['preClose']) ?? 0;
    final cr = _ndn(lp['chgRate']) ?? 0;
    return FundRankItemData(
      rank: i + 1,
      name: _firstStr(item, const ['shortName', 'name'], '--'),
      code: _firstStr(item, const ['code'], '--'),
      symbolId: '${item['symbolId'] ?? ''}',
      netValue: preClose.toStringAsFixed(4),
      rate: _fmtRate(cr),
      trend: cr >= 0 ? 'up' : 'down',
    );
  }

  // ==================== Navigation ====================

  void _goQuoteDetails(QuoteCardData c) {
    if (c.symbolId.isEmpty) return; // goQuoteDetails: if (!item?.symbolId) return
    context.push(
        '/market-details?symbolId=${c.symbolId}&name=${Uri.encodeComponent(c.name)}&source=hotIndex');
  }

  void _goSectorDetails(SectorRankItem r) {
    context.push('/market-details?symbolId=${r.symbolId}&name=${Uri.encodeComponent(r.name)}');
  }

  void _goFundDetails(FundRankItemData r) {
    context.push('/position-details?symbolId=${r.symbolId}');
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // 头部渐变背景（含 hero 高光），延伸到状态栏后面
        Positioned(top: 0, left: 0, right: 0, child: MarketHeaderBackground(isDark: isDark, topPad: topPad)),
        SafeArea(
          child: Column(children: [
            // 头部内容固定在顶部，不随下拉刷新滚动
            MarketHeaderContent(
              isDark: isDark,
              onSearch: () => context.push('/optional-search'), // goSearchPage → /pages/optional/search
            ),
            Expanded(
              child: ZPagingRefresh(
                isDark: isDark,
                onRefresh: _loadData,
                child: Column(children: [
                  QuoteStrip(isDark: isDark, cards: _quoteCards, onTap: _goQuoteDetails),
                  const SizedBox(height: 9), // margin-top 18rpx
                  DistributionPanel(isDark: isDark, items: _distData),
                  const SizedBox(height: 9),
                  SectorRankPanel(
                    isDark: isDark,
                    items: _sectorRanks,
                    onMore: () => context.push('/plate-ranking'),
                    onItemTap: _goSectorDetails,
                  ),
                  const SizedBox(height: 9),
                  FundRankPanel(
                    isDark: isDark,
                    items: _fundRanks,
                    // 1:1 源码跳 ./selectedlist（基金榜单页）
                    onMore: () => context.push('/selected-list'),
                    onItemTap: _goFundDetails,
                  ),
                  const SizedBox(height: 69), // page-scroll padding-bottom 138rpx
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ===== Helpers =====
  double? _ndn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _firstStr(Map<String, dynamic> m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return fallback;
  }

  String _fmtSigned(double? v) => v == null ? '--' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';
  String _fmtRate(double? v) => v == null ? '--' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  String _fmtPrice(double? v) => v == null ? '--' : v.toStringAsFixed(2);
}
