import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/profit_detail_top_list.dart';

/// 盈亏明细页 — 1:1 复刻 uni-app pages/user/profit-detail.vue
/// 盈利TOP5/亏损TOP5 Tab + 奖牌排行 + 进度条
///
/// 路由 query 参数（对齐 uni-app onLoad options）:
///   bookId — 账本ID，'all'/空 表示全部账本
///   date   — 'yyyy-MM-dd'，空表示当日
///
/// 说明：uni-app 源码中的日期栏与日期选择弹层触发入口已被注释（dead code），
/// 本页同样不展示日期栏；弹层结构已按源码迁移为
/// widgets/profit_detail_date_sheet.dart 的 ProfitDetailDateSheet，留待启用。
class ProfitDetailPage extends StatefulWidget {
  final String? bookId;
  final String? date;

  const ProfitDetailPage({super.key, this.bookId, this.date});

  @override
  State<ProfitDetailPage> createState() => _ProfitDetailPageState();
}

class _ProfitDetailPageState extends State<ProfitDetailPage> {
  final ApiClient _api = ApiClient();

  String _activeTab = 'profit'; // 'profit' / 'loss'
  List<Map<String, dynamic>> _rawItems = const [];
  late final String _bookId = widget.bookId ?? '';
  // 日期选择弹层入口在 uni-app 源码中已被注释，故当前不可变；启用弹层时去掉 final
  late final String _selectedDate = widget.date ?? '';

  /// uni-app: bookId === 'all' ? undefined : Number(bookId)
  int? get _apiBookId => (_bookId.isEmpty || _bookId == 'all') ? null : int.tryParse(_bookId);

  static double _toNum(dynamic v) {
    if (v == null) return 0;
    return num.tryParse(v.toString())?.toDouble() ?? 0;
  }

  /// uni-app list computed：按 Tab 过滤 → 绝对值降序 → 取前5 → 归一化进度
  List<ProfitDetailItem> get _list {
    final isProfit = _activeTab == 'profit';
    final filtered = _rawItems.where((i) {
      final n = _toNum(i['changeAmount']);
      return isProfit ? n > 0 : n < 0;
    }).toList()
      ..sort((a, b) => _toNum(b['changeAmount']).abs().compareTo(_toNum(a['changeAmount']).abs()));
    final top = filtered.take(5).toList();

    var maxAbs = 1.0;
    for (final i in top) {
      final v = _toNum(i['changeAmount']).abs();
      if (v > maxAbs) maxAbs = v;
    }

    return [
      for (final i in top)
        ProfitDetailItem(
          name: (i['shortName'] ?? i['name'] ?? '--').toString(),
          value: _fmtAmount(_toNum(i['changeAmount'])),
          percentage: (_toNum(i['changeAmount']).abs() / maxAbs * 100).round(),
        ),
    ];
  }

  /// uni-app: fmt = n => `${n >= 0 ? '+' : ''}${Number(n || 0).toFixed(2)}`
  static String _fmtAmount(double n) => '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetail());
  }

  Future<void> _fetchDetail() async {
    try {
      // uni-app getProfitDayDetail(date, bookId)：空值参数不携带
      final query = <String, dynamic>{};
      if (_selectedDate.isNotEmpty) query['date'] = _selectedDate;
      final bookId = _apiBookId;
      if (bookId != null) query['bookId'] = bookId;
      final res = await _api.get(ApiEndpoints.profitDay, queryParameters: query.isEmpty ? null : query);
      final body = res.data;
      final raw = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : const []);
      if (!mounted) return;
      setState(() {
        _rawItems = raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      });
    } catch (_) {/* 静默处理（对齐 uni-app console.error） */}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: CustomNavBar(
        title: '盈亏明细',
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // .page-content padding: 20rpx 0
          child: ProfitDetailTopList(
            isDark: isDark,
            activeTab: _activeTab,
            items: _list,
            onTabChange: (tab) {
              if (_activeTab == tab) return;
              setState(() => _activeTab = tab);
            },
          ),
        ),
      ),
    );
  }
}
