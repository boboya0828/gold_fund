import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/market_details_chart.dart';

/// 行情详情页 — 1:1 复刻 zdj-v1 pages/market/details.vue
///
/// 结构：顶部行情卡(涨跌幅/价格/涨跌额 + 热度/排名[源码硬编码文案] +
///   实时|业绩 切换 + fl_chart 折线 + 业绩区间切换) → 榜单卡(热搜榜/涨幅榜 各取前10)。
/// 接口：minuteKline/{symbolId}、dailyLines/range、FundHeatTop、FundQuoteTop。
/// 注意：源码未接 SignalR；热度/排名两格在模板中是硬编码文本（146.3亿 / 1/555），1:1 保留。
class MarketDetailsPage extends ConsumerStatefulWidget {
  final String symbolId;
  final String? name;

  /// 入口来源（源码仅用于日志，这里保留兼容）
  final String? source;

  /// 初始榜单 tab：hot / rise（源码 onLoad options.tab）
  final String? initialTab;

  const MarketDetailsPage({
    super.key,
    required this.symbolId,
    this.name,
    this.source,
    this.initialTab,
  });

  @override
  ConsumerState<MarketDetailsPage> createState() => _MarketDetailsPageState();
}

class _MarketDetailsPageState extends ConsumerState<MarketDetailsPage> {
  final ApiClient _api = ApiClient();

  // ===== 榜单 tab（热搜/涨幅）=====
  late String _activeTab =
      (widget.initialTab == 'hot' || widget.initialTab == 'rise') ? widget.initialTab! : 'hot';
  Map<String, List<_BoardItem>> _boardMap = const {'hot': [], 'rise': []};

  // ===== 头部行情 =====
  double _changeRatio = 0;
  double _latestPrice = 0;
  double _changeValue = 0;

  // ===== 图表：实时/业绩 =====
  String _infoTab = 'realtime';
  String _perfRange = '6m';
  List<double?> _chartValues = []; // 243 分钟轴，null=无数据
  List<double?> _chartPrices = [];
  List<String> _perfDates = [];
  List<double> _perfValues = [];
  List<String> _perfLabels = [];
  final Map<String, _PerfData> _perfCache = {};

  // ===== 触摸 tooltip =====
  bool _tooltipShow = false;
  String _tooltipTime = '';
  String _tooltipPrice = '';
  double _tooltipYield = 0;

  /// 固定分钟交易轴：09:30-11:30 + 13:00-15:00（含两端，共 243 点）
  static final List<String> _minuteTimeline = _buildMinuteTimeline();
  static List<String> _buildMinuteTimeline() {
    List<String> span(int sh, int sm, int eh, int em) {
      final out = <String>[];
      var cur = sh * 60 + sm;
      final end = eh * 60 + em;
      while (cur <= end) {
        out.add('${(cur ~/ 60).toString().padLeft(2, '0')}:${(cur % 60).toString().padLeft(2, '0')}');
        cur++;
      }
      return out;
    }

    return [...span(9, 30, 11, 30), ...span(13, 0, 15, 0)];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBoardData();
      if (widget.symbolId.isNotEmpty) _fetchChartData();
    });
  }

  // ==================== 接口 ====================

  /// 分时数据 → 图表 + 头部（fetchChartData）
  Future<void> _fetchChartData() async {
    try {
      final res = await _api.get('${ApiEndpoints.assetSymbolMinuteKline}/${widget.symbolId}');
      final body = res.data;
      final payload = body is Map ? body['data'] : body;
      if (payload is! List || payload.isEmpty) return;

      // 按时间正序（后端可能倒序返回）
      final sorted = payload
          .whereType<Map>()
          .map((e) => (time: _normalizeMinuteTime(e['time']), item: e))
          .where((e) => e.time.isNotEmpty)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      final minuteMap = <String, double>{};
      final priceMap = <String, double?>{};
      for (final e in sorted) {
        final chg = _toNum(e.item['chgRate']);
        if (chg != null) minuteMap[e.time] = double.parse(chg.toStringAsFixed(3));
        priceMap[e.time] = _normalizeChartPrice(e.item['close']);
      }

      final values = _minuteTimeline.map((t) => minuteMap[t]).toList();
      final prices = _minuteTimeline.map((t) => priceMap[t]).toList();

      // 头部取最后一个有效点
      final Map last = sorted.isNotEmpty
          ? sorted.last.item
          : (payload.last is Map ? payload.last as Map : const {});
      if (!mounted) return;
      setState(() {
        _chartValues = values;
        _chartPrices = prices;
        _changeRatio = _toNum(last['chgRate']) ?? 0;
        _latestPrice = _toNum(last['close']) ?? 0;
        _changeValue = _toNum(last['chgAmt']) ?? 0;
      });
    } catch (_) {}
  }

  /// 业绩日K（fetchPerformanceData，带区间缓存）
  Future<void> _fetchPerformanceData() async {
    if (widget.symbolId.isEmpty) return;
    final cacheKey = '${widget.symbolId}-$_perfRange';
    final cached = _perfCache[cacheKey];
    if (cached != null) {
      setState(() {
        _perfDates = cached.dates;
        _perfValues = cached.values;
        _perfLabels = cached.labels;
      });
      return;
    }
    try {
      const rangeDays = {'1m': 30, '3m': 90, '6m': 180, '1y': 365, '3y': 1095};
      final end = DateTime.now();
      final start = DateTime(end.year, end.month, end.day - (rangeDays[_perfRange] ?? 180));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final res = await _api.get(
        ApiEndpoints.assetSymbolDailyLinesRange,
        queryParameters: {'symbolId': widget.symbolId, 'startDate': fmt(start), 'endDate': fmt(end)},
      );
      final body = res.data;
      final payload = body is Map ? body['data'] : body;
      if (payload is! List || payload.isEmpty) return;

      double? lineValue(Map item) {
        for (final k in const ['accNav', 'close', 'preClose']) {
          final v = _toNum(item[k]);
          if (v != null && v > 0) return v;
        }
        return null;
      }

      final sorted = payload
          .whereType<Map>()
          .where((e) => e['tradeDate'] != null)
          .toList()
        ..sort((a, b) => '${a['tradeDate']}'.compareTo('${b['tradeDate']}'));
      // 源码 reduce((bv, item) => bv || (resolveLineValue(item) || 1), 0) || 1
      // 等价于：首条的 lineValue，无则 1
      final baseValue = sorted.isEmpty ? 1.0 : (lineValue(sorted.first) ?? 1.0);

      final dates = <String>[];
      final values = <double>[];
      for (final e in sorted) {
        final cur = lineValue(e) ?? baseValue;
        final ds = '${e['tradeDate']}';
        dates.add(ds.length > 10 ? ds.substring(0, 10) : ds); // slice(0, 10)
        values.add((cur - baseValue) / baseValue * 100);
      }
      final len = dates.length;
      final labels = List<String>.filled(len, '');
      if (len > 0) {
        labels[0] = dates[0];
        if (len > 1) labels[len - 1] = dates[len - 1];
        final mid = (len - 1) ~/ 2;
        if (mid > 0 && mid < len - 1) labels[mid] = dates[mid];
      }
      _perfCache[cacheKey] = _PerfData(dates: dates, values: values, labels: labels);
      if (!mounted) return;
      setState(() {
        _perfDates = dates;
        _perfValues = values;
        _perfLabels = labels;
      });
    } catch (_) {}
  }

  /// 热搜榜 + 涨幅榜（fetchBoardData，各取前 10）
  Future<void> _fetchBoardData() async {
    try {
      final res = await Future.wait([
        _api.get(ApiEndpoints.marketFundHeatTop),
        _api.get(ApiEndpoints.marketFundQuoteTop),
      ]);
      if (!mounted) return;
      setState(() {
        _boardMap = {
          'hot': _formatBoardList(res[0].data),
          'rise': _formatBoardList(res[1].data),
        };
      });
    } catch (_) {}
  }

  List<_BoardItem> _formatBoardList(dynamic body) {
    final payload = body is Map ? body['data'] : body;
    final List<dynamic> all;
    if (payload is Map && payload['all'] is List) {
      all = payload['all'] as List;
    } else if (payload is List) {
      all = payload;
    } else {
      all = const [];
    }
    return all.take(10).toList().asMap().entries.map((e) {
      final item = e.value is Map ? e.value as Map : const {};
      final rate = _resolveBoardRate(item);
      return _BoardItem(
        rank: e.key + 1,
        name: _firstStr(item, const ['shortName', 'name'], '--'),
        value: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        symbolId: '${item['symbolId'] ?? ''}',
      );
    }).toList();
  }

  /// resolveBoardRate：changeRatio/chgRate/… 候选字段 → 价格/昨收兜底 → 0
  double _resolveBoardRate(Map item) {
    final lp = item['latestPrice'] is Map ? item['latestPrice'] as Map : const {};
    final candidates = [
      lp['changeRatio'], lp['chgRate'],
      item['changeRatio'], item['chgRate'], item['increaseRatio'], item['riseRatio'],
    ];
    for (final c in candidates) {
      final rate = _toNum(c);
      if (rate != null) return rate;
    }
    final price = _toNum(lp['latestPrice'] ?? item['latestPrice'] ?? item['price'] ?? item['currentPrice']);
    final preClose = _toNum(lp['preClose'] ?? item['preClose'] ?? item['netValue']);
    if (price != null && preClose != null && preClose != 0) {
      return (price - preClose) / preClose * 100;
    }
    return 0;
  }

  // ==================== 事件 ====================

  void _switchInfoTab(String tab) {
    if (_infoTab == tab) return;
    setState(() {
      _infoTab = tab;
      _tooltipShow = false;
    });
    // watch(activeDetailsInfoTab)：切业绩且未加载时拉数据
    if (tab == 'performance' && _perfValues.isEmpty) _fetchPerformanceData();
  }

  void _switchPerfRange(String range) {
    if (_perfRange == range) return;
    setState(() {
      _perfRange = range;
      _tooltipShow = false;
    });
    _fetchPerformanceData();
  }

  /// 图表触摸回调：updateAxisPointer → tooltipData；松开 → 隐藏
  void _onTouchSpot(int? idx) {
    if (idx == null) {
      if (_tooltipShow) setState(() => _tooltipShow = false);
      return;
    }
    final isRealtime = _infoTab == 'realtime';
    if (isRealtime) {
      if (idx < 0 || idx >= _chartValues.length) return;
      final y = _chartValues[idx];
      if (y == null) {
        if (_tooltipShow) setState(() => _tooltipShow = false);
        return;
      }
      final p = _chartPrices[idx];
      setState(() {
        _tooltipShow = true;
        _tooltipTime = _minuteTimeline[idx];
        _tooltipPrice = p == null ? '--' : '$p';
        _tooltipYield = y;
      });
    } else {
      if (idx < 0 || idx >= _perfValues.length) return;
      setState(() {
        _tooltipShow = true;
        _tooltipTime = _perfDates[idx];
        _tooltipPrice = '${_perfValues[idx].toStringAsFixed(2)}%';
        _tooltipYield = _perfValues[idx];
      });
    }
  }

  void _goToPosition(_BoardItem item) {
    if (item.symbolId.isEmpty) return;
    context.push('/position-details?symbolId=${item.symbolId}');
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendColor = _changeRatio >= 0 ? const Color(0xFFFC4E4F) : const Color(0xFF20B083);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8F5F2),
      body: Stack(children: [
        // .page-container 背景图 selectlist.png（100% × 474rpx=237），暗色无图
        if (!isDark)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/img/selectlist.png',
                height: 237,
                width: double.infinity,
                fit: BoxFit.fill,
                // 资源待注册进 pubspec（见迁移报告）；未注册时退回纯色背景
                errorBuilder: (_, _, _) => const SizedBox(height: 237),
              ),
            ),
          ),
        Column(children: [
          // bgState1 + darkMask：浅色透明(透出背景图)，深色 #202125
          CustomNavBar(
            title: widget.name ?? '板块详情',
            backgroundColor: isDark ? AppColors.darkSurface : Colors.transparent,
            titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 0), // 18rpx 18rpx 0
              child: Column(children: [
                _buildInfoCard(isDark, trendColor),
                const SizedBox(height: 8), // page-content gap 16rpx
                Expanded(child: _buildRankCard(isDark)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  /// 顶部行情卡 .detailsinfo
  Widget _buildInfoCard(bool isDark, Color trendColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10), // 20rpx 18rpx
      child: Column(children: [
        _buildHeaderRow(isDark, trendColor),
        const SizedBox(height: 11), // detailsinfo-tab-wrap margin-top 22rpx
        _buildInfoTabWrap(isDark),
        const SizedBox(height: 10), // echart margin-top 20rpx
        _buildChartArea(isDark),
        if (_infoTab == 'performance') _buildPerfRangeRow(isDark),
      ]),
    );
  }

  /// .detailsinfo-t：左 涨跌幅+价格+涨跌额，右 热度/排名（源码硬编码）
  Widget _buildHeaderRow(bool isDark, Color trendColor) {
    final metricColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8D8D);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${_changeRatio >= 0 ? '+' : ''}${_changeRatio.toStringAsFixed(2)}%',
            style: AppTextStyles.num(29, color: trendColor), // 58rpx
          ),
          const SizedBox(height: 9), // detailsinfo__sub margin-top 18rpx
          Row(children: [
            Text(_latestPrice.toStringAsFixed(2), style: AppTextStyles.num(12, color: trendColor)),
            const SizedBox(width: 11), // gap 22rpx
            Text(
              _changeValue > 100
                  ? (_changeValue / 100).toStringAsFixed(2)
                  : _changeValue.toStringAsFixed(2),
              style: AppTextStyles.num(12, color: trendColor),
            ),
          ]),
        ]),
        // .detailsinfo__right：grid 52rpx+110rpx，gap 28rpx，行间距 20rpx
        Padding(
          padding: const EdgeInsets.only(top: 3), // padding-top 6rpx
          child: Column(children: [
            _metricRow('热度', '146.3亿',
                // --hot 浅色 #FC4E4F；暗色被 .theme-dark .detailsinfo__value 覆盖为 #A7ADB8
                isDark ? const Color(0xFFA7ADB8) : const Color(0xFFFC4E4F),
                metricColor),
            const SizedBox(height: 10),
            _metricRow('排名', '1/555', metricColor, metricColor),
          ]),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value, Color valueColor, Color labelColor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 26, // 52rpx
        child: Text(label, style: AppTextStyles.cn(12, color: labelColor, height: 1)),
      ),
      const SizedBox(width: 14), // column-gap 28rpx
      SizedBox(
        width: 55, // 110rpx
        child: Text(value,
            style: AppTextStyles.num(14, color: valueColor), textAlign: TextAlign.right),
      ),
    ]);
  }

  /// .detailsinfo-tab-wrap：右侧 实时|业绩 胶囊 + 触摸 tooltip 覆盖条
  Widget _buildInfoTabWrap(bool isDark) {
    return SizedBox(
      height: 27, // 54rpx
      child: Stack(children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 106, // 212rpx
            height: 27,
            padding: const EdgeInsets.all(2), // 4rpx
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282828) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14), // 28rpx
            ),
            child: Row(children: [
              _infoTabItem('实时', 'realtime', isDark),
              _infoTabItem('业绩', 'performance', isDark),
            ]),
          ),
        ),
        // .echart__tooltip（pointer-events:none，不挡 tab 点击）
        if (_tooltipShow)
          Positioned.fill(child: IgnorePointer(child: _buildTooltipBar(isDark))),
      ]),
    );
  }

  Widget _infoTabItem(String label, String value, bool isDark) {
    final active = _infoTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchInfoTab(value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? (isDark ? AppColors.darkSurface : Colors.white) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active && !isDark
                ? const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 4)]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.cn(
              14, // 28rpx
              height: 1,
              color: active
                  ? const Color(0xFFF7B523)
                  : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADADAD)),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部自定义 tooltip 条（按下显示 时间/价格/涨幅）
  Widget _buildTooltipBar(bool isDark) {
    final yieldColor = _tooltipYield >= 0 ? const Color(0xFFF5465C) : const Color(0xFF20B083);
    final yieldText =
        '${_tooltipYield >= 0 ? '+' : ''}${_tooltipYield.toStringAsFixed(2)}%';
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB5A090);
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 10), // 0 20rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF5202125) : const Color(0xF5FFFFFF), // .96 透明度
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2D33) : const Color(0x148C644D),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x47000000) : const Color(0x1F8C644D), // rgba(140,100,77,.12)
            offset: const Offset(0, 2), // 4rpx
            blurRadius: 8, // 16rpx
          ),
        ],
      ),
      child: Row(children: [
        Text(
          _tooltipTime,
          style: AppTextStyles.num(12, color: isDark ? AppColors.darkText : const Color(0xFF8C644D)),
        ),
        const SizedBox(width: 10), // gap 6 + time margin-right 4
        Text('价格', style: AppTextStyles.cn(11, color: labelColor)),
        const SizedBox(width: 6),
        Text(_tooltipPrice, style: AppTextStyles.num(13, color: yieldColor, weight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('涨幅', style: AppTextStyles.cn(11, color: labelColor)),
        const SizedBox(width: 6),
        Text(yieldText, style: AppTextStyles.num(13, color: yieldColor, weight: FontWeight.w600)),
      ]),
    );
  }

  /// .echart：200 高图表 + 左上 maxPct / 左下 minPct 标签
  Widget _buildChartArea(bool isDark) {
    final source = _infoTab == 'realtime' ? _chartValues : _perfValues;
    final filtered = source.whereType<double>().toList();
    final maxV = filtered.isEmpty ? 0.0 : filtered.reduce((a, b) => a > b ? a : b);
    final minV = filtered.isEmpty ? 0.0 : filtered.reduce((a, b) => a < b ? a : b);
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8A8F9B);

    return SizedBox(
      height: 200, // 400rpx
      child: Stack(children: [
        Positioned.fill(
          child: MarketDetailsChart(
            isDark: isDark,
            isRealtime: _infoTab == 'realtime',
            isRise: _changeRatio >= 0,
            realtimeValues: _chartValues,
            perfValues: _perfValues,
            perfLabels: _perfLabels,
            onTouchSpot: _onTouchSpot,
          ),
        ),
        // .echart__label（pointer-events:none）
        Positioned(
          top: 0,
          left: 0,
          child: IgnorePointer(
            child: Text('${maxV.toStringAsFixed(2)}%', style: AppTextStyles.num(11, color: labelColor)),
          ),
        ),
        Positioned(
          bottom: 20, // bottom: 10% of 200
          left: 0,
          child: IgnorePointer(
            child: Text(
              minV >= 0 ? '+${minV.toStringAsFixed(2)}%' : '${minV.toStringAsFixed(2)}%',
              style: AppTextStyles.num(11, color: labelColor),
            ),
          ),
        ),
      ]),
    );
  }

  /// .perf-range：近1月/3月/6月/1年/3年
  Widget _buildPerfRangeRow(bool isDark) {
    const ranges = [('1m', '近1月'), ('3m', '近3月'), ('6m', '近6月'), ('1y', '近1年'), ('3y', '近3年')];
    return Padding(
      padding: const EdgeInsets.only(top: 8), // margin-top 16rpx
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ranges.map((r) {
          final active = _perfRange == r.$1;
          return GestureDetector(
            onTap: () => _switchPerfRange(r.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4), // 8rpx 22rpx
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE05665)
                    : (isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(10), // 20rpx
              ),
              child: Text(
                r.$2,
                style: AppTextStyles.cn(
                  12, // 24rpx
                  color: active
                      ? Colors.white
                      : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8D8D)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 榜单卡 .rank-card（热搜榜/涨幅榜）
  Widget _buildRankCard(bool isDark) {
    final list = _boardMap[_activeTab] ?? const <_BoardItem>[];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A60451F), // rgba(96,69,31,.04)
                  offset: Offset(0, 4), // 8rpx
                  blurRadius: 12, // 24rpx
                ),
              ],
      ),
      child: Column(children: [
        // .tab-row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), // 24rpx 24rpx 0
          child: Row(children: [
            _boardTabItem('热搜榜', 'hot', isDark),
            const SizedBox(width: 28), // gap 56rpx
            _boardTabItem('涨幅榜', 'rise', isDark),
          ]),
        ),
        // .table-head：grid 58rpx 1fr 150rpx, gap 16rpx
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 6), // 26rpx 24rpx 12rpx
          child: Row(children: [
            SizedBox(width: 29, child: Text('排名', style: _headStyle(isDark))),
            const SizedBox(width: 8),
            Expanded(child: Text('基金名称', style: _headStyle(isDark))),
            const SizedBox(width: 8),
            SizedBox(
              width: 75,
              child: Text('涨幅', style: _headStyle(isDark), textAlign: TextAlign.right),
            ),
          ]),
        ),
        // .table-scroll
        Expanded(
          child: list.isEmpty
              // .empty-state：顶部横向居中（非垂直居中）
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60), // 120rpx
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('暂无榜单数据', style: AppTextStyles.cn(14, color: const Color(0xFFB8AFAA))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  itemBuilder: (context, i) => _buildBoardRow(list[i], isDark),
                ),
        ),
      ]),
    );
  }

  TextStyle _headStyle(bool isDark) =>
      AppTextStyles.cn(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8D8D), height: 1);

  Widget _boardTabItem(String label, String value, bool isDark) {
    final active = _activeTab == value;
    final color = active
        ? (isDark ? AppColors.darkText : const Color(0xFF333333))
        : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9F9F9F));
    return GestureDetector(
      onTap: () => setState(() => _activeTab = value),
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9), // 18rpx
          child: Text(
            label,
            style: AppTextStyles.cn(16, color: color, weight: active ? FontWeight.w700 : FontWeight.w500, height: 1),
          ),
        ),
        if (active)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 19, // 38rpx
                height: 2, // 4rpx
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6670),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildBoardRow(_BoardItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _goToPosition(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFFCFCFC),
              width: 0.5, // 1rpx
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), // 26rpx 24rpx
        child: Row(children: [
          SizedBox(
            width: 29, // 58rpx
            child: Text(
              item.rank.toString().padLeft(2, '0'), // formatRank
              style: AppTextStyles.num(14, color: _rankColor(item.rank, isDark), weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.cn(14,
                  color: isDark ? AppColors.darkText : const Color(0xFF1E1917), height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75, // 150rpx
            child: Text(
              item.value,
              // .table-row__value 固定 #ff5d5e（源码无暗色覆盖，明暗同色）
              style: AppTextStyles.num(15, color: const Color(0xFFFF5D5E)),
              textAlign: TextAlign.right,
            ),
          ),
        ]),
      ),
    );
  }

  /// rankColorClass：top1 #ef9d11 / top2 #9fa3af / top3 #d48b58 / 默认 #333(暗 #D7DAE0)
  Color _rankColor(int rank, bool isDark) {
    switch (rank) {
      case 1:
        return const Color(0xFFEF9D11);
      case 2:
        return const Color(0xFF9FA3AF);
      case 3:
        return const Color(0xFFD48B58);
      default:
        return isDark ? AppColors.darkText : const Color(0xFF333333);
    }
  }

  // ==================== 工具 ====================

  double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _firstStr(Map m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return fallback;
  }

  /// normalizeMinuteTime：从 ISO/“HH:mm[:ss]” 中取 HH:mm（兼容时区串）
  String _normalizeMinuteTime(dynamic value) {
    final text = '${value ?? ''}';
    if (text.isEmpty) return '';
    final dt = RegExp(r'(?:T|\s)(\d{1,2}):(\d{2})(?::\d{2})?').firstMatch(text);
    if (dt != null) return '${dt.group(1)!.padLeft(2, '0')}:${dt.group(2)!}';
    final t = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (t != null) return '${t.group(1)!.padLeft(2, '0')}:${t.group(2)!}';
    return '';
  }

  /// normalizeChartPrice：>100 视为放大 100 倍
  double? _normalizeChartPrice(dynamic value) {
    final p = _toNum(value);
    if (p == null) return null;
    return p > 100
        ? double.parse((p / 100).toStringAsFixed(2))
        : double.parse(p.toStringAsFixed(2));
  }
}

class _BoardItem {
  final int rank;
  final String name, value, symbolId;
  const _BoardItem({required this.rank, required this.name, required this.value, required this.symbolId});
}

class _PerfData {
  final List<String> dates, labels;
  final List<double> values;
  const _PerfData({required this.dates, required this.values, required this.labels});
}
