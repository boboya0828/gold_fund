import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/listed_nav_row.dart';

const _epDailyLinesAfter = ApiEndpoints.assetSymbolDailyLinesAfter; // GET ?symbolId&afterDate&count

/// 历史净值（上市净值）页 — uni-app 对应: pages/index/fund/listed-net-value.vue
///
/// 分页加载日线净值（每页 30 条，初始 afterDate=今天），上拉触底（lower-threshold 60）
/// 以最后一条的 tradeDate 作为下次 afterDate 追加，按日期去重；hasMore = 返回条数 >= 30。
/// 本页面未使用 umeng 埋点（源码即无）。
class ListedNetValuePage extends StatefulWidget {
  final int? symbolId;

  const ListedNetValuePage({super.key, this.symbolId});

  @override
  State<ListedNetValuePage> createState() => _ListedNetValuePageState();
}

/// 净值行（源码 formatItem 产物）
class _NavItem {
  final String date; // tradeDate 前 10 位
  final String unitValue; // closeStr ?? close ?? accNav ?? '--'
  final String change; // '+x.xx%' / '--'
  final bool isRise; // (changeRatio ?? 0) >= 0
  final String? tradeDate; // 用于加载更多的 afterDate

  const _NavItem({
    required this.date,
    required this.unitValue,
    required this.change,
    required this.isRise,
    required this.tradeDate,
  });
}

class _ListedNetValuePageState extends State<ListedNetValuePage> {
  static const _pageSize = 30; // 源码 PAGE_SIZE

  final ApiClient _api = ApiClient();
  final ScrollController _scrollCtl = ScrollController();

  List<_NavItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollCtl.addListener(_onScroll);
    // 源码 onLoad：初始 afterDate 取当天（yyyy-MM-dd）
    final sid = widget.symbolId;
    if (sid == null) return;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadHistory(today, append: false);
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  /// 源码 scroll-view lower-threshold=60 → 距底 60px 触发加载更多
  void _onScroll() {
    if (!_scrollCtl.hasClients) return;
    final pos = _scrollCtl.position;
    if (pos.pixels >= pos.maxScrollExtent - 60) _loadMoreHistory();
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 源码 formatItem
  _NavItem _formatItem(Map item) {
    final cr = _toDouble(item['changeRatio']) ?? 0;
    final rawDate = item['tradeDate']?.toString();
    final date = rawDate != null && rawDate.length >= 10 ? rawDate.substring(0, 10) : '--';
    final unit = item['closeStr'] ?? item['close'] ?? item['accNav'] ?? '--';
    return _NavItem(
      date: date,
      unitValue: '$unit',
      change: item['changeRatio'] != null ? '${cr >= 0 ? '+' : ''}${cr.toStringAsFixed(2)}%' : '--',
      isRise: cr >= 0,
      tradeDate: rawDate != null && rawDate.length >= 10 ? rawDate.substring(0, 10) : null,
    );
  }

  /// 源码 loadHistoryData：拉取 afterDate 之后的日线，按日期去重后替换/追加
  Future<void> _loadHistory(String afterDate, {required bool append}) async {
    final sid = widget.symbolId;
    if (sid == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(
        _epDailyLinesAfter,
        queryParameters: {'symbolId': sid, 'afterDate': afterDate, 'count': _pageSize},
      );
      final body = res.data;
      final lines = body is Map && body['data'] is List ? body['data'] as List : const [];
      final formatted = [for (final l in lines) if (l is Map) _formatItem(l)];
      // 源码：按 date 去重
      final existing = _items.map((e) => e.date).toSet();
      final newItems = formatted.where((e) => !existing.contains(e.date)).toList();
      if (mounted) {
        setState(() {
          _items = append ? [..._items, ...newItems] : newItems;
          _hasMore = lines.length >= _pageSize;
        });
      }
    } catch (_) {
      // 源码: console.error('获取净值数据失败')
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 源码 loadMoreHistory：以最后一条 tradeDate 为 afterDate 追加
  void _loadMoreHistory() {
    if (_isLoading || !_hasMore || _items.isEmpty) return;
    final afterDate = _items.last.tradeDate;
    if (afterDate != null) _loadHistory(afterDate, append: true);
  }

  /// 源码 loadMoreStatus
  String get _loadMoreStatus {
    if (_isLoading) return '加载中...';
    if (!_hasMore) return '没有更多';
    return '上拉加载更多';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF6F6F6),
      body: Column(
        children: [
          // useAppTheme: 浅 导航 #ffffff/字 #333333；深 导航 #202125/字 #D7DAE0
          CustomNavBar(
            title: '历史净值',
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            child: Container(
              // .page-grid + ml-4/mr-4/mt-4（1rem=16），padding 16rpx=8，圆角 16rpx=8
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  ListedNavTableHeader(isDark: isDark),
                  Expanded(
                    child: _items.isNotEmpty ? _buildList(isDark) : _buildEmpty(isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 源码 .net-list：scroll-view，行间距 8rpx=4，底部加载状态
  Widget _buildList(bool isDark) {
    return ListView.separated(
      controller: _scrollCtl,
      padding: EdgeInsets.zero,
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 4), // gap 8rpx
      itemBuilder: (context, index) {
        if (index == _items.length) {
          // .net-list-status / --done
          final done = !_hasMore;
          return Padding(
            padding: const EdgeInsets.only(top: 9, bottom: 4), // 18rpx 0 8rpx
            child: Text(
              _loadMoreStatus,
              textAlign: TextAlign.center,
              style: AppTextStyles.cn(
                11, // 22rpx
                color: isDark
                    ? const Color(0xFFA7ADB8)
                    : (done ? const Color(0xFFC2C2C2) : const Color(0xFFB6B6B6)),
              ),
            ),
          );
        }
        final item = _items[index];
        return ListedNavRow(
          isDark: isDark,
          date: item.date,
          unitValue: item.unitValue,
          change: item.change,
          isRise: item.isRise,
        );
      },
    );
  }

  /// 源码 .empty-state：暂无净值数据
  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 18), // 48rpx 0 36rpx
      child: Text(
        '暂无净值数据',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9)), // 26rpx
      ),
    );
  }
}
