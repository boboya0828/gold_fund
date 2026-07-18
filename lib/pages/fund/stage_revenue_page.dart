import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/stage_revenue_row.dart';
import 'widgets/stage_revenue_tab_bar.dart';

/// 阶段收益页 — uni-app 对应: pages/index/fund/stage-revenue.vue
///
/// 数据：getSymbolIndicators（GET assetSymbolIndicators?symbolId=）两次 ——
/// 先沪深300（固定 symbolId '1031413'，与源码一致），后本基金；失败则空态占位。
/// 「阶段」Tab 为近1/3/6月、近1年对月度指标求和；其余 Tab 按期数逐项对比并算超额收益。
/// 本页面未使用 umeng 埋点（源码即无）。
class StageRevenuePage extends StatefulWidget {
  final int? symbolId;

  const StageRevenuePage({super.key, this.symbolId});

  @override
  State<StageRevenuePage> createState() => _StageRevenuePageState();
}

class _StageRevenuePageState extends State<StageRevenuePage> {
  final ApiClient _api = ApiClient();

  static const _tabs = [
    StageRevenueTab('阶段', 'stage'),
    StageRevenueTab('月度', 'month'),
    StageRevenueTab('季度', 'quarter'),
    StageRevenueTab('半年', 'halfYear'),
    StageRevenueTab('年度', 'year'),
  ];

  String _activeTab = 'stage';

  /// 本基金 / 沪深300 周期涨幅指标 {month/quarter/halfYear/year: [{date, value}]}
  Map<String, dynamic> _fundData = {};
  Map<String, dynamic> _hsData = {};

  late List<StageGainRow> _rows = _buildEmptyStageList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 源码 formatPercentText
  static String _fmt(double? v) => v == null ? '--' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

  static bool? _tone(double? v) => v == null ? null : v >= 0;

  /// 源码 buildEmptyStageList
  static List<StageGainRow> _buildEmptyStageList() => const [
        StageGainRow(date: '近1月', fund: '--', hs300: '--', excess: '--'),
        StageGainRow(date: '近3月', fund: '--', hs300: '--', excess: '--'),
        StageGainRow(date: '近6月', fund: '--', hs300: '--', excess: '--'),
        StageGainRow(date: '近1年', fund: '--', hs300: '--', excess: '--'),
      ];

  Map<String, dynamic> _asDataMap(dynamic body) {
    if (body is Map) {
      final data = body['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return body.cast<String, dynamic>();
    }
    return {};
  }

  /// 源码 onLoad：先取沪深300 指标，再取本基金指标，最后 updateStageGainList
  Future<void> _load() async {
    final sid = widget.symbolId;
    if (sid == null) return;
    try {
      final hsRes = await _api.get(ApiEndpoints.assetSymbolIndicators, queryParameters: {'symbolId': '1031413'});
      final fundRes = await _api.get(ApiEndpoints.assetSymbolIndicators, queryParameters: {'symbolId': '$sid'});
      _hsData = _asDataMap(hsRes.data);
      _fundData = _asDataMap(fundRes.data);
      _updateStageGainList();
    } catch (_) {
      // 源码: console.error('获取收益数据失败') → 空态占位
      _fundData = {};
      _hsData = {};
      if (mounted) setState(() => _rows = _buildEmptyStageList());
    }
  }

  /// 源码 getNumericIndicatorValues：提取有限数值
  List<double> _numericValues(Map<String, dynamic> data, String key) {
    final items = data[key];
    if (items is! List || items.isEmpty) return [];
    return [
      for (final item in items) ?_toDouble(item is Map ? item['value'] : null),
    ];
  }

  /// 源码 sumRecentIndicatorValues：前 count 项求和，无数据返回 null
  double? _sumRecent(Map<String, dynamic> data, String key, int count) {
    final values = _numericValues(data, key).take(count).toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b);
  }

  /// 源码 formatIndicatorDate：原样返回，缺省用 fallback
  static String _formatDate(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  /// 源码 updateStageGainList
  void _updateStageGainList() {
    if (_activeTab == 'stage') {
      const stages = [('近1月', 1), ('近3月', 3), ('近6月', 6), ('近1年', 12)];
      final rows = [
        for (final (label, count) in stages)
          _buildSumRow(label, _sumRecent(_fundData, 'month', count), _sumRecent(_hsData, 'month', count)),
      ];
      if (mounted) setState(() => _rows = rows);
      return;
    }
    const prefixMap = {'month': '月度', 'quarter': '季度', 'halfYear': '半年', 'year': '年度'};
    final rows = _mapPeriodRows(_activeTab, prefixMap[_activeTab] ?? '');
    if (mounted) setState(() => _rows = rows.isNotEmpty ? rows : _buildEmptyStageList());
  }

  StageGainRow _buildSumRow(String label, double? fundVal, double? hsVal) {
    final excessVal = (fundVal != null && hsVal != null) ? fundVal - hsVal : null;
    return StageGainRow(
      date: label,
      fund: _fmt(fundVal),
      fundUp: _tone(fundVal),
      hs300: _fmt(hsVal),
      hs300Up: _tone(hsVal),
      excess: _fmt(excessVal),
      excessUp: _tone(excessVal),
    );
  }

  /// 源码 mapData：按月/季/半年/年逐项对比（同下标配对沪深300）
  List<StageGainRow> _mapPeriodRows(String key, String prefix) {
    final items = _fundData[key];
    if (items is! List || items.isEmpty) return [];
    final hsItems = _hsData[key];
    return [
      for (var i = 0; i < items.length; i++)
        _mapOne(items[i], (hsItems is List && i < hsItems.length) ? hsItems[i] : null, i, prefix),
    ];
  }

  StageGainRow _mapOne(dynamic item, dynamic hsItem, int index, String prefix) {
    final fundVal = _toDouble(item is Map ? item['value'] : null);
    final hsVal = _toDouble(hsItem is Map ? hsItem['value'] : null);
    final excessVal = (fundVal != null && hsVal != null) ? fundVal - hsVal : null;
    return StageGainRow(
      date: _formatDate(item is Map ? item['date'] : null, '$prefix${index + 1}'),
      fund: _fmt(fundVal),
      fundUp: _tone(fundVal),
      hs300: _fmt(hsVal),
      hs300Up: _tone(hsVal),
      excess: _fmt(excessVal),
      excessUp: _tone(excessVal),
    );
  }

  /// 源码 handleStageTabChange
  void _handleTabChange(String value) {
    if (_activeTab == value) return;
    setState(() => _activeTab = value);
    _updateStageGainList();
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
            title: '阶段收益',
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
                  StageRevenueTabBar(
                    tabs: _tabs,
                    activeValue: _activeTab,
                    onChanged: _handleTabChange,
                    isDark: isDark,
                  ),
                  StageRevenueTableHeader(isDark: isDark),
                  Expanded(
                    child: _rows.isNotEmpty
                        ? ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _rows.length,
                            itemBuilder: (context, index) =>
                                StageRevenueRow(row: _rows[index], isDark: isDark),
                          )
                        : _buildEmpty(isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 源码 .empty-state：暂无收益数据
  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 18), // 48rpx 0 36rpx
      child: Text(
        '暂无收益数据',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9)), // 26rpx
      ),
    );
  }
}
