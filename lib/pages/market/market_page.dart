import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';

/// 行情页面 - 1:1 复刻 uni-app pages/market/index.uvue
class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});
  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage> {
  final ApiClient _api = ApiClient();

  // ---- 1:1 复刻 zdj pages/market/index.vue 数字颜色 ----
  // zdj $color-green / .is-down: #00ADA0 (light & dark, no dark mode override)
  static const _downColor = Color(0xFF00ADA0);
  // zdj $color-red / .is-up: #E05665 = AppColors.upColor, 保持一致

  List<QuoteCard> _quoteCards = [];
  List<DistItem> _distData = [];
  List<RankItem> _sectorRanks = [];
  List<FundRankItem> _fundRanks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchHotIndex(), _fetchSectorRanks(),
      _fetchFundRanks(), _fetchChangeCount(),
    ]);
    if (mounted) setState(() {});
  }

  // ==================== API calls ====================

  Future<void> _fetchHotIndex() async {
    try {
      final res = await _api.get(ApiEndpoints.marketHotIndex);
      final data = res.data;
      if (data?['code'] == 200 && data!['data'] is List) {
        _quoteCards = (data['data'] as List).cast<Map<String, dynamic>>()
            .asMap().entries.map((e) => _normQuote(e.value, e.key)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchSectorRanks() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundSectorRanking);
      final data = res.data;
      if (data?['code'] == 200 && data!['data'] is List) {
        _sectorRanks = (data['data'] as List).cast<Map<String, dynamic>>()
            .take(6).toList().asMap().entries.map((e) => _normSector(e.value, e.key)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchFundRanks() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundPickTop);
      final data = res.data;
      if (data?['code'] == 200) {
        var list = data!['data'];
        if (list is Map) list = list['all'] ?? list;
        if (list is List) {
          _fundRanks = (list as List).cast<Map<String, dynamic>>()
              .take(6).toList().asMap().entries.map((e) => _normFund(e.value, e.key)).toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchChangeCount() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundChangeCount);
      final data = res.data;
      var cc = data?['data']?['changeCount'] ?? data?['changeCount'];
      if (cc is List) {
        final list = (cc as List).cast<Map<String, dynamic>>();
        final mx = list.fold<int>(1, (m, e) => _n(e['count']) > m ? _n(e['count']) : m);
        _distData = list.map((e) {
          final c = _n(e['count']);
          final n = (e['name'] as String?) ?? '';
          String t = 'up';
          if (n.startsWith('-') || n.startsWith('<') || n.startsWith('<=') || n.startsWith('~-')) t = 'down';
          if (n == '0') t = 'flat';
          final h = mx > 0 ? ((c / mx) * 73).round().clamp(2, 73) : 2;
          return DistItem(label: n, value: c, height: h, type: t);
        }).toList();
      }
    } catch (_) {}
  }

  // ==================== Normalization ====================

  QuoteCard _normQuote(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final price = _nd(lp['latestPrice'] ?? item['latestPrice'] ?? item['price'] ?? item['currentPrice']);
    final preClose = _nd(lp['preClose'] ?? item['preClose'] ?? item['netValue']);
    var change = _nd(lp['change'] ?? item['increase'] ?? item['changeAmount']);
    if (change == 0 && price != 0 && preClose != 0) change = price - preClose;
    var rate = _nd(lp['changeRatio'] ?? lp['chgRate'] ?? item['increaseRatio']);
    if (rate == 0 && change != 0 && preClose != 0) rate = (change / preClose) * 100;
    return QuoteCard(
      symbolId: '${item['symbolId'] ?? ''}',
      name: (item['shortName'] ?? '热门指数${i + 1}') as String,
      price: price.toStringAsFixed(2),
      change: _fs(change),
      rate: '${change >= 0 ? "+" : ""}${rate.toStringAsFixed(2)}%',
      trend: rate < 0 ? 'down' : 'up');
  }

  RankItem _normSector(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final rate = _nd(lp['chgRate']) * 100;
    return RankItem(rank: i + 1, name: (item['shortName'] ?? '板块${i + 1}') as String,
      rate: '${rate >= 0 ? "+" : ""}${rate.toStringAsFixed(2)}%', symbolId: '${item['symbolId'] ?? ''}',
      trend: rate < 0 ? 'down' : 'up');
  }

  FundRankItem _normFund(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final preClose = _nd(lp['preClose']);
    final cr = _nd(lp['chgRate']);
    return FundRankItem(rank: i + 1, name: (item['shortName'] ?? '--') as String,
      code: (item['code'] ?? '--') as String, symbolId: '${item['symbolId'] ?? ''}',
      netValue: preClose.toStringAsFixed(4),
      rate: '${cr >= 0 ? "+" : ""}${cr.toStringAsFixed(2)}%',
      trend: cr >= 0 ? 'up' : 'down');
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
        // Hero bg 层放在 SafeArea 外层，延伸到状态栏后面 (状态栏透明)，
        // 高度补上 topPad 以保持底边位置不变，否则状态栏那一条会露出纯色 Scaffold 背景。
        Positioned(top: 0, left: 0, right: 0, height: 210 + topPad,
          child: Container(color: isDark ? AppColors.darkBg : const Color(0xFFf9ecd6))),
        SafeArea(
          child: RefreshIndicator(
            color: AppColors.upColor,
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _header(isDark, topPad),
                _quoteStrip(isDark),
                const SizedBox(height: 9),
                _distPanel(isDark),
                const SizedBox(height: 9),
                _sectorPanel(isDark),
                const SizedBox(height: 9),
                _fundPanel(isDark),
                const SizedBox(height: 69),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ===== Header with hero bg =====
  Widget _header(bool isDark, double tp) {
    return Stack(children: [
      // Content
      Container(
        color: isDark ? AppColors.darkBg : const Color(0xFFf7e7cf),
        padding: EdgeInsets.only(top: tp > 0 ? 0 : 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
          child: Row(children: [
            Image.asset('assets/images/img/jianbei.png', width: 18, height: 18),
            const SizedBox(width: 5),
            Text('行情榜单', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black)),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                height: 40, padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: Colors.white.withAlpha(240), borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  Expanded(child: Text('输入名称编号', style: AppTextStyles.cn(13, color: const Color(0xFFbbb2aa)))),
                  const SizedBox(width: 8),
                  Icon(AppIcons.search, size: 22, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA6A6A6)),
                ])),
            )),
          ])),
      ),
    ]);
  }

  // ===== Quote cards strip (border-radius 5px) =====
  Widget _quoteStrip(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _quoteCards.map((c) {
          final up = c.trend == 'up';
          final tc = up ? AppColors.upColor : _downColor;
          return GestureDetector(
            onTap: () => context.push('/market-details?symbolId=${c.symbolId}&name=${Uri.encodeComponent(c.name)}'),
            child: Container(
              width: 96, margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              decoration: BoxDecoration(
              color: isDark ? (up ? const Color(0xFF282828) : const Color(0xFF24282A))
                  : (up ? const Color(0xFFFCF6F6) : const Color(0xFFF4FAFB)),
              border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFE9E3E5)),
              borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(c.name, style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
              const SizedBox(height: 4),
              Text(c.price, style: AppTextStyles.num(18, color: tc, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(c.change, style: AppTextStyles.cn(11, color: tc)),
                const SizedBox(width: 5), Text(c.rate, style: AppTextStyles.cn(11, color: tc)),
                const SizedBox(width: 5), Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 14, color: tc),
              ]),
            ])));
        }).toList()),
      ),
    );
  }

  // ===== Distribution panel =====
  Widget _distPanel(bool isDark) {
    final downTotal = _distData.where((d) => d.type == 'down').fold<int>(0, (s, d) => s + d.value);
    final upTotal = _distData.where((d) => d.type == 'up').fold<int>(0, (s, d) => s + d.value);
    final total = downTotal + upTotal;
    final downPct = total == 0 ? 50 : (downTotal * 100 ~/ total);
    final valColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF515b76);
    final lblColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8b8b8b);
    final sumColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF868686);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('今日涨跌分布', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black)),
        SizedBox(height: 103, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end,
          children: _distData.map((d) {
            final bc = d.type == 'down' ? const Color(0xFF16b85f) : (d.type == 'flat' ? const Color(0xFF9ea7bc) : const Color(0xFFff4d57));
            return SizedBox(width: 30, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${d.value}', style: AppTextStyles.num(11, color: valColor)),
              const SizedBox(height: 4),
              Container(height: d.height.toDouble(), width: 14,
                decoration: BoxDecoration(color: bc, borderRadius: const BorderRadius.vertical(top: Radius.circular(2)))),
              const SizedBox(height: 5), Text(d.label, style: AppTextStyles.num(9, color: lblColor)),
            ]));
          }).toList()),
        ),
        const SizedBox(height: 13),
        Row(children: [
          Text('下跌', style: AppTextStyles.cn(11, color: sumColor)), const SizedBox(width: 3),
          Text('$downTotal', style: AppTextStyles.num(11, color: const Color(0xFF16b85f), weight: FontWeight.w600)),
          const SizedBox(width: 7),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999),
            child: SizedBox(height: 12, child: Row(children: [
              Flexible(flex: downPct, child: Container(color: const Color(0xFF16b85f))),
              Flexible(flex: 100 - downPct, child: Container(color: const Color(0xFFff4d57))),
            ])))),
          const SizedBox(width: 7),
          Text('$upTotal', style: AppTextStyles.num(11, color: const Color(0xFFff4d57), weight: FontWeight.w600)),
          const SizedBox(width: 3), Text('上涨', style: AppTextStyles.cn(11, color: sumColor)),
        ]),
      ]),
    );
  }

  // ===== Sector panel =====
  Widget _sectorPanel(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(5),
    ),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: SizedBox(height: 330, child: Column(children: [
      _panelTitle('板块收益排行', isDark, onMore: () => context.push('/plate-ranking')),
      const SizedBox(height: 17),
      _sectorHead(isDark),
      ..._sectorRanks.map((r) => _sectorRow(r, isDark)),
    ])));

  // ===== Fund panel =====
  Widget _fundPanel(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(5),
    ),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 9),
    child: SizedBox(height: 440, child: Column(children: [
      _panelTitle('基金自选榜单', isDark, onMore: () => context.push('/search')),
      const SizedBox(height: 17),
      _fundHead(isDark),
      ..._fundRanks.map((r) => _fundRow(r, isDark)),
    ])));

  Widget _panelTitle(String t, bool isDark, {VoidCallback? onMore}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(t, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black)),
    GestureDetector(onTap: onMore, child: Row(children: [
      Text('更多', style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA6A6A6))),
      const SizedBox(width: 2),
      Icon(Icons.chevron_right, size: 14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA6A6A6)),
    ])),
  ]);

  Widget _sectorHead(bool isDark) {
    final hc = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF808080);
    return Container(padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F2)))),
      child: Row(children: [
        SizedBox(width: 32, child: Text('排名', style: AppTextStyles.cn(12, color: hc), textAlign: TextAlign.center)),
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('板块名称', style: AppTextStyles.cn(12, color: hc)))),
        SizedBox(width: 78, child: Text('涨跌幅', style: AppTextStyles.cn(12, color: hc), textAlign: TextAlign.right)),
      ]));
  }

  Widget _fundHead(bool isDark) {
    final hc = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF808080);
    return Container(padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F2)))),
      child: Row(children: [
        SizedBox(width: 32, child: Text('排名', style: AppTextStyles.cn(12, color: hc), textAlign: TextAlign.center)),
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('基金名称', style: AppTextStyles.cn(12, color: hc)))),
        SizedBox(width: 68, child: Text('净值', style: AppTextStyles.cn(12, color: hc), textAlign: TextAlign.right)),
        SizedBox(width: 68, child: Text('涨跌幅', style: AppTextStyles.cn(12, color: hc), textAlign: TextAlign.right)),
      ]));
  }

  Widget _sectorRow(RankItem r, bool isDark) {
    final up = r.trend == 'up';
    final tc = up ? AppColors.upColor : _downColor;
    return GestureDetector(
      onTap: r.symbolId.isNotEmpty
          ? () => context.push('/market-details?symbolId=${r.symbolId}&name=${Uri.encodeComponent(r.name)}')
          : null,
      child: Container(height: 41,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFebe6e1)))),
        child: Row(children: [
          SizedBox(width: 32, child: Text(_fr(r.rank), style: AppTextStyles.num(14, color: _rc(r.rank, isDark), weight: FontWeight.w600), textAlign: TextAlign.center)),
          Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r.name,
            style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF1e1917)), maxLines: 1, overflow: TextOverflow.ellipsis))),
          SizedBox(width: 78, child: Text(r.rate, style: AppTextStyles.num(15, color: tc), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }

  Widget _fundRow(FundRankItem r, bool isDark) {
    final up = r.trend == 'up';
    final tc = up ? AppColors.upColor : _downColor;
    final netColor = isDark ? const Color(0xFFEF6672) : AppColors.upColor; // 1:1 uni-app
    return GestureDetector(
      onTap: r.symbolId.isNotEmpty
          ? () => context.push('/position-details?symbolId=${r.symbolId}&assetType=3')
          : null,
      child: Container(height: 49,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFebe6e1)))),
      child: Row(children: [
        SizedBox(width: 32, child: Text(_fr(r.rank), style: AppTextStyles.num(14, color: _rc(r.rank, isDark), weight: FontWeight.w600), textAlign: TextAlign.center)),
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(r.name, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF1e1917)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4), Text(r.code, style: AppTextStyles.num(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9b9b9b))),
        ]))),
        SizedBox(width: 68, child: Text(r.netValue, style: AppTextStyles.num(15, color: netColor), textAlign: TextAlign.right)),
        SizedBox(width: 68, child: Text(r.rate, style: AppTextStyles.num(15, color: tc), textAlign: TextAlign.right)),
      ])),
    );
  }

  // ===== Helpers =====
  double _nd(dynamic v) { if (v == null) return 0; if (v is num) return v.toDouble(); return double.tryParse(v.toString()) ?? 0; }
  int _n(dynamic v) { if (v == null) return 0; if (v is num) return v.toInt(); return int.tryParse(v.toString()) ?? 0; }
  String _fs(double v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(2)}';
  String _fr(int r) => r < 10 ? '0$r' : '$r';
  Color _rc(int r, bool d) => r == 1 ? const Color(0xFFee9f1c) : r == 2 ? const Color(0xFF8e8e98) : r == 3 ? const Color(0xFFd28d5f) : (d ? AppColors.darkText : const Color(0xFF191919));
}

class QuoteCard { final String symbolId, name, price, change, rate, trend; const QuoteCard({required this.symbolId, required this.name, required this.price, required this.change, required this.rate, required this.trend}); }
class DistItem { final String label, type; final int value, height; const DistItem({required this.label, required this.value, required this.height, required this.type}); }
class RankItem { final int rank; final String name, rate, symbolId, trend; const RankItem({required this.rank, required this.name, required this.rate, required this.symbolId, required this.trend}); }
class FundRankItem { final int rank; final String name, code, symbolId, netValue, rate, trend; const FundRankItem({required this.rank, required this.name, required this.code, required this.symbolId, required this.netValue, required this.rate, required this.trend}); }
