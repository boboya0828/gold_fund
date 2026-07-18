import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/market_models.dart';

/// 板块排行页 — 1:1 复刻 zdj-v1 pages/market/plate-ranking.vue
///
/// 白卡片(圆角 10rpx=5)内 排名/板块名称/涨跌幅 全量列表。
/// 接口：fundSectorRanking（rate = latestPrice.chgRate || 0）。
/// 行点击 → /market-details?symbolId=&name=。
class PlateRankingPage extends ConsumerStatefulWidget {
  const PlateRankingPage({super.key});

  @override
  ConsumerState<PlateRankingPage> createState() => _PlateRankingPageState();
}

class _PlateRankingPageState extends ConsumerState<PlateRankingPage> {
  final ApiClient _api = ApiClient();
  List<SectorRankItem> _ranks = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSectorRanks());
  }

  Future<void> _fetchSectorRanks() async {
    try {
      final res = await _api.get(ApiEndpoints.marketFundSectorRanking);
      final body = res.data;
      final payload = body is Map ? body['data'] : body;
      if (payload is! List) return;
      if (!mounted) return;
      setState(() {
        _ranks = payload
            .cast<Map<String, dynamic>>()
            .asMap()
            .entries
            .map((e) => _normalize(e.value, e.key))
            .toList();
      });
    } catch (_) {}
  }

  /// normalizeSectorRank：rate = Number(latestPrice.chgRate) || 0；trend 按 rate 正负
  SectorRankItem _normalize(Map<String, dynamic> item, int i) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? const {};
    final rate = _toNum(lp['chgRate']) ?? 0;
    return SectorRankItem(
      rank: i + 1,
      name: _firstStr(item, const ['shortName', 'name', 'symbolName'], '板块${i + 1}'),
      rate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%', // formatRate
      trend: rate < 0 ? 'down' : 'up',
      symbolId: '${item['symbolId'] ?? ''}',
    );
  }

  void _goToDetails(SectorRankItem item) {
    if (item.symbolId.isEmpty) return;
    context.push('/market-details?symbolId=${item.symbolId}&name=${Uri.encodeComponent(item.name)}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF1F1F3),
      body: Column(children: [
        // bgState:false → 纯色导航栏：浅 #ffffff / 深 #202125
        CustomNavBar(
          title: '板块排行',
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          child: ListView(
            // mt-4/ml-4/mr-4 = 1rem = 16px
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(5), // 10rpx
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12), // 36rpx 40rpx 24rpx
                child: Column(children: [
                  _buildHead(isDark),
                  for (var i = 0; i < _ranks.length; i++)
                    _buildRow(_ranks[i], isDark, i == _ranks.length - 1),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// .sector-table-head
  Widget _buildHead(bool isDark) {
    final style =
        AppTextStyles.cn(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF808080));
    return Container(
      padding: const EdgeInsets.only(bottom: 8), // 16rpx
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F2),
            width: 0.5, // 1rpx
          ),
        ),
      ),
      child: Row(children: [
        SizedBox(width: 32, child: Text('排名', style: style, textAlign: TextAlign.center)), // 64rpx
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('板块名称', style: style))),
        SizedBox(width: 78, child: Text('涨跌幅', style: style, textAlign: TextAlign.right)), // 156rpx
      ]),
    );
  }

  /// .sector-row
  Widget _buildRow(SectorRankItem item, bool isDark, bool isLast) {
    final up = item.trend == 'up';
    // is-up #E05665 / is-down #00ADA0（源码无暗色覆盖，明暗同色）
    final tc = up ? AppColors.upColor : kMarketDownColor;
    return GestureDetector(
      onTap: () => _goToDetails(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 41, // 82rpx
        decoration: BoxDecoration(
          border: isLast
              ? null // :last-child border-bottom: 0
              : Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEBE6E1),
                    width: 0.5,
                  ),
                ),
        ),
        child: Row(children: [
          SizedBox(
            width: 32,
            child: Text(
              '${item.rank}', // formatRank: String(rank)（本页不补零）
              style: AppTextStyles.num(14, color: marketRankColor(item.rank, isDark), weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12), // 24rpx
              child: Text(
                item.name,
                style: AppTextStyles.cn(14,
                    color: isDark ? AppColors.darkText : const Color(0xFF1E1917), height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(item.rate, style: AppTextStyles.num(15, color: tc), textAlign: TextAlign.right),
          ),
        ]),
      ),
    );
  }

  double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _firstStr(Map<String, dynamic> m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return fallback;
  }
}
