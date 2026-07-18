import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import 'widgets/position_details_bottom_actions.dart';
import 'widgets/position_details_chart_card.dart';
import 'widgets/position_details_heavyweight.dart';
import 'widgets/position_details_hero_card.dart';
import 'widgets/position_details_history.dart';
import 'widgets/position_details_models.dart';
import 'widgets/position_details_profit_calendar.dart';

/// 持仓详情页
/// uni-app 对应: pages/index/fund/position-details.vue（5396 行，按优先级迁移核心区块）
///
/// 平台专有能力（未迁移）：微信小程序条件编译、umeng 埋点 trackUmengEvent、
/// chinese-days 节假日库（日历「休」标记暂以周末跳过代替）。
class PositionDetailsPage extends ConsumerStatefulWidget {
  final String symbolId;
  final int assetType;
  final int? assetId;
  final int? bookId;
  final bool fromAllBooks;

  const PositionDetailsPage({
    super.key,
    required this.symbolId,
    this.assetType = 3,
    this.assetId,
    this.bookId,
    this.fromAllBooks = false,
  });

  @override
  ConsumerState<PositionDetailsPage> createState() => _PositionDetailsPageState();
}

class _PositionDetailsPageState extends ConsumerState<PositionDetailsPage> {
  // ===== 接口端点（统一引用 ApiEndpoints）=====
  static const _epSymbolInfo = ApiEndpoints.assetSymbolInfo; // GET /{symbolId} 标的详情
  static const _epSymbolsInfo = ApiEndpoints.assetSymbolBatchInfo; // POST [symbolId]
  static const _epFundHoldings = ApiEndpoints.assetSymbolFundHoldings; // GET /{symbolId}
  static const _epDailyLinesAfter = ApiEndpoints.assetSymbolDailyLinesAfter; // GET ?symbolId&afterDate&count
  static const _epFavoriteBySymbol = ApiEndpoints.favoriteBySymbol; // GET /{symbolId}
  static const _epFavoriteRemoveBySymbol = ApiEndpoints.favoriteRemoveBySymbol; // DELETE /{symbolId}
  // 注：ApiEndpoints.assetSymbolDailyLinesRange 注释标注 POST，
  // 但 uni-app api.js 实际为 GET ?symbolId&startDate&endDate，本页按 uni-app 使用 GET。

  final _api = ApiClient();

  // ===== 页面状态 =====
  bool _loading = true;
  bool _navbarScrolled = false;
  Map<String, dynamic> _info = {};
  String _shortName = '';
  String _symbol = '';
  String _fundTypeName = '';
  int? _assetType; // 实际资产类型（7=贵金属）

  // 持仓
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _positionBooks = [];
  List<PdBookTab> _bookTabs = [];
  Map<String, dynamic> _positionDetail = {};
  int _selectedBookId = -1;
  bool _bookDropdownOpen = false;
  bool _isFavorite = false;

  // 图表
  String _activeChartTab = 'sector';
  List<PdSectorSeries> _sectorSeries = [];
  String _sectorTooltipTime = '';
  String _activeTrendRange = '6m';
  List<PdTrendPoint> _trendPoints = [];
  final Map<String, List<PdTrendPoint>> _trendCache = {};
  bool _trendLoading = false;
  int _trendHoverIndex = -1;

  static const _trendRangeTabs = <Map<String, Object>>[
    {'label': '近1月', 'value': '1m', 'days': 30},
    {'label': '近3月', 'value': '3m', 'days': 90},
    {'label': '近6月', 'value': '6m', 'days': 180},
    {'label': '近1年', 'value': '1y', 'days': 365},
    {'label': '近3年', 'value': '3y', 'days': 1095},
  ];
  static const _stageTabs = <Map<String, String>>[
    {'label': '阶段', 'value': 'stage'},
    {'label': '月度', 'value': 'month'},
    {'label': '季度', 'value': 'quarter'},
    {'label': '半年', 'value': 'halfYear'},
    {'label': '年度', 'value': 'year'},
  ];

  // 收益 / 历史
  String _activeStageTab = 'stage';
  Map<String, dynamic> _fundIndicators = {};
  Map<String, dynamic> _hsIndicators = {};
  List<PdHistoryRow> _historyRows = [];
  List<Map<String, dynamic>>? _heavyweight;

  // 收益日历
  String _activeCalendarView = '日';
  bool _showCalendarPercent = false;
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;
  List<PdCalendarDay> _calendarDays = [];
  Map<int, String> _monthlyProfitMap = {};
  Map<int, double> _monthlyRateMap = {};
  Map<int, String> _yearlyProfitMap = {};
  Map<String, dynamic>? _calendarSummary;
  int? _selectedCalendarDay;
  int? _selectedMonthCard;
  int? _selectedYearCard;

  // 弹幕
  static const _danmuStorageKey = 'positionDetailsDanmuOn';
  bool _isDanmuOn = true;
  int _danmuRenderKey = 0;
  List<PdDanmuItem> _serverDanmu = [];
  final List<PdDanmuItem> _userDanmu = [];
  final Set<String> _hiddenDanmuIds = {};
  int _barrageRise = 0;
  int _barrageFall = 0;

  bool get _isPreciousMetal => _assetType == 7 || widget.assetType == 7;
  bool get _hasPosition => _positionDetail.isNotEmpty;
  int get _fundId => int.tryParse('${_info['symbolId'] ?? widget.symbolId}') ?? 0;

  List<PdDanmuItem> get _visibleDanmu =>
      [..._serverDanmu, ..._userDanmu].where((e) => !_hiddenDanmuIds.contains(e.id)).toList();

  @override
  void initState() {
    super.initState();
    _loadDanmuState();
    _loadAll();
  }

  // ===================== 数据加载 =====================

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] != null) return data['data'];
    return data;
  }

  Future<void> _loadDanmuState() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool(_danmuStorageKey);
    if (on == false && mounted) setState(() => _isDanmuOn = false);
  }

  Future<void> _loadAll() async {
    final sid = widget.symbolId;
    if (sid.isEmpty) return;
    try {
      await _loadPosition(sid);
      // 标的详情
      final infoRes = await _api.get('$_epSymbolInfo/$sid');
      final data = _unwrap(infoRes.data);
      if (data is Map<String, dynamic>) {
        _info = data;
        _info['symbolId'] = data['symbolId'] ?? sid;
        _shortName = data['shortName']?.toString() ?? data['name']?.toString() ?? '';
        _fundTypeName = data['fundTypeName']?.toString() ?? '';
        _symbol = data['code']?.toString() ?? '';
        _assetType ??= data['assetType'] is num ? (data['assetType'] as num).toInt() : null;
      }
      if (mounted) setState(() => _loading = false);
      // 并行加载次级数据（失败各自忽略）
      unawaited(_syncFavoriteStatus(sid));
      unawaited(_loadBarrages());
      unawaited(_loadBarrageTrend());
      unawaited(_loadSectorSeries());
      unawaited(_loadHeavyweight(sid));
      unawaited(_loadIndicators(sid));
      unawaited(_loadHistory(sid));
      unawaited(_loadTrend(_activeTrendRange));
      unawaited(_loadCalendar());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 持仓（含账本）— uni-app hendleGetfundInfo
  Future<void> _loadPosition(String sid) async {
    try {
      final res = await _api.get('/asset/api/Asset/symbol/$sid');
      final data = _unwrap(res.data);
      List list = [];
      if (data is Map && data['list'] is List) list = data['list'];
      if (data is List) list = data;
      _assets = list.whereType<Map<String, dynamic>>().toList();
      _assetType ??= () {
        for (final a in _assets) {
          if (a['assetType'] is num) return (a['assetType'] as num).toInt();
        }
        return null;
      }();
    } catch (_) {
      _assets = [];
    }
    // 账本名称
    final bookNames = <int, String>{};
    try {
      final booksRes = await _api.get(ApiEndpoints.assetBooks);
      final bd = _unwrap(booksRes.data);
      if (bd is List) {
        for (final b in bd) {
          if (b is Map && b['bookId'] is num) {
            bookNames[(b['bookId'] as num).toInt()] =
                b['bookName']?.toString() ?? b['name']?.toString() ?? '账本${b['bookId']}';
          }
        }
      }
    } catch (_) {}
    final seen = <int>{};
    _positionBooks = [];
    for (final item in _assets) {
      final bid = (item['bookId'] as num?)?.toInt();
      if (bid == null || bid == -1 || seen.contains(bid)) continue;
      seen.add(bid);
      _positionBooks.add({...item, 'bookName': bookNames[bid] ?? '账本$bid'});
    }
    _bookTabs = [
      if (widget.fromAllBooks && _positionBooks.length > 1) const PdBookTab(-1, '全部'),
      ..._positionBooks.map((b) => PdBookTab((b['bookId'] as num).toInt(), b['bookName']?.toString() ?? '账本')),
    ];
    _selectPositionDetail(widget.bookId);
  }

  /// uni-app selectPositionDetail
  void _selectPositionDetail(int? targetBookId) {
    Map<String, dynamic>? summary;
    for (final a in _assets) {
      final aid = (a['assetId'] as num?)?.toInt();
      final bid = (a['bookId'] as num?)?.toInt();
      if (bid == -1 && (summary == null || aid == -1)) summary = a;
    }
    Map<String, dynamic>? matched;
    if (targetBookId != null && targetBookId != -1) {
      for (final a in _assets) {
        if ((a['bookId'] as num?)?.toInt() == targetBookId) {
          matched = a;
          break;
        }
      }
    }
    final isAll = targetBookId == null || targetBookId == -1;
    final next = isAll
        ? (summary ?? (_assets.isNotEmpty ? _assets.first : <String, dynamic>{}))
        : (matched ?? summary ?? (_assets.isNotEmpty ? _assets.first : <String, dynamic>{}));
    setState(() {
      _positionDetail = next;
      _selectedBookId = isAll ? -1 : ((matched != null ? targetBookId : (next['bookId'] as num?)?.toInt()) ?? -1);
    });
  }

  Future<void> _syncFavoriteStatus(String sid) async {
    try {
      final res = await _api.get('$_epFavoriteBySymbol/$sid');
      final data = _unwrap(res.data);
      final isFav = data is List ? data.isNotEmpty : (data is Map ? (data['items'] is List ? (data['items'] as List).isNotEmpty : true) : false);
      if (mounted) setState(() => _isFavorite = isFav);
    } catch (_) {}
  }

  /// 关联涨跌（板块分钟线）— uni-app hendleplateList
  Future<void> _loadSectorSeries() async {
    try {
      final raw = _info['relatedIndexSymbolIds'];
      final ids = <int>[];
      if (raw is List) {
        for (final e in raw) {
          final v = e is Map ? (e['symbolId'] ?? e['id']) : e;
          final n = int.tryParse('$v');
          if (n != null && n > 0) ids.add(n);
        }
      } else if (raw != null) {
        for (final s in '$raw'.split(RegExp(r'[,，]'))) {
          final n = int.tryParse(s.trim());
          if (n != null && n > 0) ids.add(n);
        }
      }
      if (ids.isEmpty) return;
      final symbolsRes = await _api.post(_epSymbolsInfo, data: ids);
      final sd = _unwrap(symbolsRes.data);
      final symbols = sd is List ? sd.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
      if (symbols.isEmpty) return;
      final result = <PdSectorSeries>[];
      var idx = 0;
      for (final s in symbols) {
        final sSid = s['symbolId'];
        try {
          final res = await _api.get('${ApiEndpoints.assetSymbolMinuteKline}/$sSid');
          final kd = _unwrap(res.data);
          if (kd is! List) continue;
          final values = <double?>[];
          final times = <String>[];
          for (final k in kd) {
            if (k is! Map) continue;
            final rate = pdNum(k['chgRate'] ?? k['changeRatio'] ?? k['increaseRatio'] ?? k['riseRatio']);
            values.add(rate == null ? null : (rate * 1000).roundToDouble() / 1000);
            times.add(k['time']?.toString() ?? '');
          }
          if (values.any((v) => v != null)) {
            result.add(PdSectorSeries(
              name: s['shortName']?.toString() ?? s['name']?.toString() ?? '关联${idx + 1}',
              color: kPdSeriesColors[idx % kPdSeriesColors.length],
              values: values,
              times: times,
            ));
          }
        } catch (_) {}
        idx++;
      }
      String tooltipTime = '';
      if (result.isNotEmpty && result.first.times.isNotEmpty) {
        final t = result.first.times.last;
        final m = RegExp(r'(\d{2}-\d{2})[ T]?.*?(\d{2}:\d{2})').firstMatch(t);
        tooltipTime = m != null ? '${m.group(1)} ${m.group(2)}' : t;
      }
      if (mounted) {
        setState(() {
          _sectorSeries = result;
          _sectorTooltipTime = tooltipTime;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHeavyweight(String sid) async {
    try {
      final res = await _api.get('$_epFundHoldings/$sid');
      final data = _unwrap(res.data);
      if (mounted) setState(() => _heavyweight = data is List ? data.whereType<Map<String, dynamic>>().toList() : []);
    } catch (_) {
      if (mounted) setState(() => _heavyweight = null);
    }
  }

  /// 阶段收益（本基金 + 沪深300 1031413）— uni-app buildStageGainList
  Future<void> _loadIndicators(String sid) async {
    try {
      final hsRes = await _api.get(ApiEndpoints.assetSymbolIndicators, queryParameters: {'symbolId': '1031413'});
      final fundRes = await _api.get(ApiEndpoints.assetSymbolIndicators, queryParameters: {'symbolId': sid});
      final hs = _unwrap(hsRes.data);
      final fund = _unwrap(fundRes.data);
      if (mounted) {
        setState(() {
          _hsIndicators = hs is Map<String, dynamic> ? hs : {};
          _fundIndicators = fund is Map<String, dynamic> ? fund : {};
        });
      }
    } catch (_) {}
  }

  /// 历史净值 — uni-app onLoad 中的 getDailyLinesAfter
  Future<void> _loadHistory(String sid) async {
    try {
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final res = await _api.get(_epDailyLinesAfter, queryParameters: {'symbolId': sid, 'afterDate': today, 'count': 10});
      final data = _unwrap(res.data);
      if (data is! List) return;
      final rows = <PdHistoryRow>[];
      for (final item in data) {
        if (item is! Map) continue;
        final date = item['tradeDate']?.toString() ?? '--';
        final unit = item['closeStr'] ?? item['close'] ?? item['accNav'] ?? '--';
        final cr = pdNum(item['changeRatio']);
        rows.add(PdHistoryRow(
          date: date.length >= 10 ? date.substring(0, 10) : date,
          unitValue: '$unit',
          change: cr == null ? '--' : '${cr >= 0 ? '+' : ''}${cr.toStringAsFixed(2)}%',
          changeRaw: cr ?? 0,
        ));
      }
      if (mounted) setState(() => _historyRows = rows);
    } catch (_) {}
  }

  /// 业绩走势 — uni-app loadTrendChartData
  Future<void> _loadTrend(String range, {bool force = false}) async {
    final sid = '${_info['symbolId'] ?? widget.symbolId}';
    if (sid.isEmpty) return;
    final cacheKey = '$sid-$range';
    if (!force && _trendCache.containsKey(cacheKey)) {
      setState(() => _trendPoints = _trendCache[cacheKey]!);
      return;
    }
    setState(() => _trendLoading = true);
    try {
      final days = _trendRangeTabs.firstWhere((t) => t['value'] == range)['days'] as int;
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days - 1));
      String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final res = await _api.get(ApiEndpoints.assetSymbolDailyLinesRange,
          queryParameters: {'symbolId': sid, 'startDate': fmt(start), 'endDate': fmt(end)});
      final data = _unwrap(res.data);
      final list = data is List ? data.whereType<Map>().toList() : <Map>[];
      list.sort((a, b) => '${a['tradeDate']}'.compareTo('${b['tradeDate']}'));
      double? base;
      double? valueOf(Map i) {
        for (final k in ['accNav', 'close', 'preClose']) {
          final v = pdNum(i[k]);
          if (v != null && v > 0) return v;
        }
        return null;
      }

      final points = <PdTrendPoint>[];
      for (final item in list) {
        if (item['tradeDate'] == null) continue;
        final v = valueOf(item);
        base ??= v;
        if (base == null || v == null) continue;
        final date = '${item['tradeDate']}';
        points.add(PdTrendPoint(
          tradeDate: date.length >= 10 ? date.substring(0, 10) : date,
          value: v,
          close: pdNum(item['close']) ?? v,
          percent: (v - base) / base * 100,
        ));
      }
      _trendCache[cacheKey] = points;
      if (mounted) setState(() => _trendPoints = points);
    } catch (_) {
      if (mounted) setState(() => _trendPoints = []);
    } finally {
      if (mounted) setState(() => _trendLoading = false);
    }
  }

  /// 收益日历 — uni-app fetchCalendarData
  Future<void> _loadCalendar() async {
    final sid = '${_info['symbolId'] ?? widget.symbolId}';
    if (sid.isEmpty) return;
    try {
      final res = await _api.get('${ApiEndpoints.profitCalendarSymbol}/$sid');
      final data = _unwrap(res.data);
      if (data is! Map) return;
      final monthly = <int, String>{};
      final monthlyRate = <int, double>{};
      if (data['monthly'] is List) {
        for (final item in data['monthly']) {
          if (item is! Map) continue;
          final m = int.tryParse('${item['period'] ?? ''}'.split('-').last);
          if (m == null) continue;
          final profit = pdNum(item['changeAmount']) ?? 0;
          monthly[m] = '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)}';
          monthlyRate[m] = pdNum(item['changeRate']) ?? 0;
        }
      }
      final yearly = <int, String>{};
      if (data['annual'] is List) {
        for (final item in data['annual']) {
          if (item is! Map) continue;
          final y = int.tryParse('${item['period'] ?? ''}');
          if (y == null) continue;
          final profit = pdNum(item['changeAmount']) ?? 0;
          yearly[y] = '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)}';
        }
      }
      final dailyMap = <String, Map>{};
      if (data['daily'] is List) {
        for (final item in data['daily']) {
          if (item is! Map) continue;
          final d = '${item['date'] ?? ''}';
          if (d.length >= 10) dailyMap[d.substring(0, 10)] = item;
        }
      }
      if (mounted) {
        setState(() {
          _monthlyProfitMap = monthly;
          _monthlyRateMap = monthlyRate;
          _yearlyProfitMap = yearly;
          _calendarSummary = data['summary'] is Map<String, dynamic> ? data['summary'] as Map<String, dynamic> : null;
          _calendarDays = _buildCalendarDays(_calendarYear, _calendarMonth, dailyMap);
          _selectedCalendarDay = null;
        });
      }
    } catch (_) {}
  }

  /// uni-app fetchCalendarData 的日格子生成（节假日库 chinese-days 未迁移，暂以周末跳过）
  List<PdCalendarDay> _buildCalendarDays(int year, int month, Map<String, Map> dailyMap) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final result = <PdCalendarDay>[];
    var firstWeekday = -1;
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final wd = date.weekday; // 1=Mon .. 7=Sun
      if (wd >= 6) continue;
      if (firstWeekday == -1) firstWeekday = wd;
      final key = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final apiItem = dailyMap[key];
      final profit = apiItem == null ? null : pdNum(apiItem['changeAmount']);
      final rate = apiItem == null ? 0.0 : (pdNum(apiItem['changeRate']) ?? 0.0);
      String fmtProfit(double n) => n == 0 ? '' : '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}';
      result.add(PdCalendarDay(
        day: d,
        value: profit == null ? '' : fmtProfit(profit),
        percentValue: rate == 0 ? '' : '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        type: profit == null ? '' : (profit > 0 ? 'rise' : (profit < 0 ? 'loss' : '')),
        isToday: date.year == today.year && date.month == today.month && date.day == today.day,
      ));
    }
    final blanks = firstWeekday > 0 ? firstWeekday - 1 : 0;
    return [...List.generate(blanks, (_) => const PdCalendarDay()), ...result];
  }

  // ===================== 弹幕 =====================

  Future<void> _loadBarrages() async {
    if (_fundId <= 0) return;
    try {
      final res = await _api.get('${ApiEndpoints.barrage}/$_fundId');
      var data = _unwrap(res.data);
      if (data is Map) data = data['list'] ?? data['items'] ?? data['records'];
      if (data is! List) return;
      final items = <PdDanmuItem>[];
      var i = 0;
      for (final raw in data) {
        if (raw is! Map) continue;
        final text = raw['content']?.toString() ?? raw['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        items.add(PdDanmuItem(
          id: '${raw['id'] ?? raw['barrageId'] ?? raw['createTime'] ?? 'server-$i'}',
          text: text,
          tone: _normalizeTone(raw['color'] ?? raw['tone']),
          topIndex: i,
          durationSec: 9 + Random().nextDouble() * 3,
          delaySec: (i % 2) * 4.8 + (i ~/ 2) * 0.6,
        ));
        i++;
      }
      if (mounted) {
        setState(() {
          _serverDanmu = items;
          _danmuRenderKey++;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBarrageTrend() async {
    if (_fundId <= 0) return;
    try {
      final res = await _api.get('${ApiEndpoints.barrageTrend}/$_fundId');
      final data = _unwrap(res.data);
      if (data is! Map) return;
      int pick(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is num) return v.toInt();
        }
        return 0;
      }

      if (mounted) {
        setState(() {
          _barrageRise = pick(['rise', 'riseCount', 'bullish', 'bullishCount', 'up', 'upCount']);
          _barrageFall = pick(['fall', 'fallCount', 'bearish', 'bearishCount', 'down', 'downCount']);
        });
      }
    } catch (_) {}
  }

  String _normalizeTone(dynamic v) {
    final t = '$v'.toLowerCase();
    return ['gray', 'red', 'green', 'blue', 'orange'].contains(t) ? t : 'gray';
  }

  String _formatBarrageCount(int count) {
    if (count <= 0) return '0人';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(count >= 100000 ? 0 : 1)}万人';
    return '$count人';
  }

  Future<void> _toggleDanmu() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDanmuOn = !_isDanmuOn;
      if (_isDanmuOn) _danmuRenderKey++;
    });
    await prefs.setBool(_danmuStorageKey, _isDanmuOn);
  }

  Future<void> _voteBarrageTrend(String status) async {
    if (_fundId <= 0) return;
    setState(() {
      if (status == 'fall') {
        _barrageFall++;
      } else {
        _barrageRise++;
      }
    });
    try {
      await _api.post(ApiEndpoints.barrageTrend, data: {'fundId': _fundId, 'status': status == 'fall' ? 'bearish' : 'bullish'});
      unawaited(_loadBarrageTrend());
    } catch (_) {}
  }

  Future<void> _sendDanmu(String text, String tone) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _userDanmu.add(PdDanmuItem(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        text: text.trim(),
        tone: tone,
        topIndex: _userDanmu.length,
        durationSec: 9 + Random().nextDouble() * 3,
        isOwn: true,
      ));
      _isDanmuOn = true;
      _danmuRenderKey++;
    });
    if (_fundId <= 0) return;
    try {
      await _api.post(ApiEndpoints.barrage, data: {'fundId': _fundId, 'content': text.trim(), 'color': tone});
    } catch (_) {}
  }

  void _reportDanmu(PdDanmuItem item) {
    setState(() => _hiddenDanmuIds.add(item.id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收到举报'), duration: Duration(seconds: 1)));
  }

  // ===================== 自选 =====================

  Future<void> _openFavoriteBookPicker() async {
    List books = [];
    try {
      final res = await _api.get(ApiEndpoints.favoriteBooks);
      final data = _unwrap(res.data);
      if (data is List) books = data;
    } catch (_) {}
    if (!mounted) return;
    int? selectedId;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return _bookSheetContainer(
            ctx,
            isDark,
            title: '添加到如下分组',
            actionText: '确认',
            children: [
              if (books.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('暂无自选账本', style: AppTextStyles.cn(12, color: AppColors.lightTextSecondary))),
                )
              else
                for (final b in books)
                  if (b is Map)
                    _bookSheetItem(
                      isDark,
                      name: b['bookName']?.toString() ?? b['name']?.toString() ?? '账本${b['bookId']}',
                      selected: selectedId == (b['bookId'] as num?)?.toInt(),
                      onTap: () => setSheet(() => selectedId = (b['bookId'] as num?)?.toInt()),
                    ),
            ],
            onConfirm: () => Navigator.pop(ctx, true),
          );
        });
      },
    );
    if (confirmed != true) return;
    try {
      await _api.post(ApiEndpoints.favorite, data: {'bookId': selectedId ?? 0, 'symbolId': _fundId});
      if (mounted) {
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加自选'), duration: Duration(seconds: 1)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加自选失败')));
    }
  }

  Future<void> _removeFavorite() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text('确认删除', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : AppColors.lightText, weight: FontWeight.w600)),
        content: Text('确定要删除「$_shortName」的自选吗？',
            style: AppTextStyles.cn(13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: AppTextStyles.cn(13, color: AppColors.lightTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('确认删除', style: AppTextStyles.cn(13, color: AppColors.upColor))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('$_epFavoriteRemoveBySymbol/${widget.symbolId}');
      if (mounted) {
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除自选'), duration: Duration(seconds: 1)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除自选失败')));
    }
  }

  // ===================== 弹窗公共 =====================

  Widget _bookSheetContainer(
    BuildContext ctx,
    bool isDark, {
    required String title,
    required String actionText,
    required List<Widget> children,
    required VoidCallback onConfirm,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SizedBox(width: 40),
              Text(title,
                  style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText, weight: FontWeight.w600)),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close, size: 18, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFBFC2CC)),
              ),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 16), children: children),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: onConfirm,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEE5668), Color(0xFFE74C62)]),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(actionText, style: AppTextStyles.cn(14, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bookSheetItem(bool isDark, {required String name, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.upColor : Colors.transparent,
              border: Border.all(color: selected ? AppColors.upColor : (isDark ? AppColors.darkTextSecondary : const Color(0xFFBFC2CC))),
            ),
            child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.lightText)),
          ),
        ]),
      ),
    );
  }

  /// 加仓/减仓 选择账本弹窗
  void _openTradeBookPicker(String tradeType) {
    if (_positionBooks.isEmpty) {
      _todo('请先添加持仓');
      return;
    }
    int? selectedId = (_positionBooks.first['bookId'] as num?)?.toInt();
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return _bookSheetContainer(
            ctx,
            isDark,
            title: '选择操作账本',
            actionText: '确定',
            children: [
              for (final b in _positionBooks)
                _bookSheetItem(
                  isDark,
                  name: b['bookName']?.toString() ?? '账本${b['bookId']}',
                  selected: selectedId == (b['bookId'] as num?)?.toInt(),
                  onTap: () => setSheet(() => selectedId = (b['bookId'] as num?)?.toInt()),
                ),
            ],
            onConfirm: () {
              Navigator.pop(ctx, true);
              _goTradePage(tradeType, selectedId);
            },
          );
        });
      },
    );
  }

  /// 年月选择弹窗（picker-view 双列）
  void _openMonthPicker() {
    final now = DateTime.now();
    final years = List.generate(7, (i) => now.year - 5 + i);
    var yearIdx = years.indexOf(_calendarYear).clamp(0, years.length - 1);
    var monthIdx = (_calendarMonth - 1).clamp(0, 11);
    final yearCtrl = FixedExtentScrollController(initialItem: yearIdx);
    final monthCtrl = FixedExtentScrollController(initialItem: monthIdx);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Text('取消', style: AppTextStyles.cn(14, color: AppColors.lightTextSecondary)),
                  ),
                  Text('选择年月', style: AppTextStyles.cn(14, color: textColor, weight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _calendarYear = years[yearIdx];
                        _calendarMonth = monthIdx + 1;
                        _selectedCalendarDay = null;
                        _selectedMonthCard = null;
                        _selectedYearCard = null;
                        _calendarDays = [];
                      });
                      _loadCalendar();
                    },
                    child: Text('确定', style: AppTextStyles.cn(14, color: AppColors.upColor)),
                  ),
                ]),
              ),
              Expanded(
                child: Row(children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: yearCtrl,
                      itemExtent: 44, // 88rpx
                      onSelectedItemChanged: (i) => yearIdx = i,
                      children: [for (final y in years) Center(child: Text('$y年', style: AppTextStyles.cn(15, color: textColor)))],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: monthCtrl,
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => monthIdx = i,
                      children: [for (var m = 1; m <= 12; m++) Center(child: Text('$m月', style: AppTextStyles.cn(15, color: textColor)))],
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// 发弹幕面板（DanmuSendPanel 简化版）
  void _openDanmuPanel() {
    const tones = [('gray', Color(0xFF8A909C)), ('red', Color(0xFFF15A65)), ('green', Color(0xFF23A982)), ('blue', Color(0xFF3478F6)), ('orange', Color(0xFFFF9F43))];
    var tone = 'red';
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('发弹幕', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText, weight: FontWeight.w600)),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close, size: 18, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFBFC2CC)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLength: 30,
                    autofocus: true,
                    style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.lightText),
                    decoration: InputDecoration(
                      hintText: '说点什么...',
                      hintStyle: AppTextStyles.cn(13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB8B8BD)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      counterStyle: AppTextStyles.num(10, color: AppColors.lightTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final t in tones)
                      GestureDetector(
                        onTap: () => setSheet(() => tone = t.$1),
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: t.$2,
                            shape: BoxShape.circle,
                            border: tone == t.$1 ? Border.all(color: isDark ? Colors.white : Colors.black54, width: 2) : null,
                          ),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        _sendDanmu(text, tone);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEE5668), Color(0xFFE74C62)]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('发送', style: AppTextStyles.cn(13, color: Colors.white)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  void _todo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  // ===================== 展示数据组装 =====================

  /// 顶部 3 指标 — uni-app onLoad summaryTopList
  List<PdMetricItem> get _summaryTop {
    final lp = _info['latestPrice'];
    final lpMap = lp is Map ? lp : const {};
    final chgRate = pdNum(lpMap['chgRate']) ?? 0;
    final latestTime = '${lpMap['latestTime'] ?? ''}';
    final m = RegExp(r'\d{4}-(\d{2}-\d{2})').firstMatch(latestTime);
    final dateSuffix = m != null ? '(${m.group(1)})' : '';
    final nav = lpMap['nav'] is Map ? lpMap['nav'] as Map : const {};
    final year1Rate = pdNum(nav['year1Rate']);
    final thirdLabel = _isPreciousMetal ? '克价$dateSuffix' : '净值$dateSuffix';
    final thirdValue = _isPreciousMetal ? '${lpMap['latestPrice'] ?? '--'}' : pdFmt(nav['latestNav'], 3);
    return [
      PdMetricItem(
        '最新涨跌${m != null ? '(${m.group(1)})' : ''}',
        '${chgRate > 0 ? '+' : ''}${pdKeepDecimals(chgRate, 2)}%',
        valueColor: chgRate > 0 ? kPdRiseColor : kPdFallColor,
      ),
      PdMetricItem('近一年', pdFmtSigned(year1Rate, 2, '%'), valueColor: pdProfitColor(year1Rate)),
      PdMetricItem(thirdLabel, thirdValue),
    ];
  }

  /// 持仓 9 指标 — uni-app hero-profit-metrics + displayPositionDetails
  List<PdMetricItem> get _positionMetrics {
    if (!_hasPosition) return [];
    final d = _positionDetail;
    final holdDay = d['holdDay'];
    return [
      PdMetricItem('持有金额', pdFmt(d['marketValue'], 2)),
      PdMetricItem(_isPreciousMetal ? '持有克重' : '持有份额', pdFmt(d['holdQuantity'])),
      PdMetricItem(_isPreciousMetal ? '持仓均价' : '持仓成本', pdFmt(d['avgCostPrice'], 4)),
      PdMetricItem('持有收益', pdFmtSigned(d['holdProfit']), valueColor: pdProfitColor(pdNum(d['holdProfit']))),
      PdMetricItem('持有收益率', pdFmtSigned(d['holdChangeRatio'], 2, '%'), valueColor: pdProfitColor(pdNum(d['holdChangeRatio']))),
      PdMetricItem('持仓占比', pdFmt(d['holdingRatio'], 2, '%')),
      PdMetricItem('当日收益', pdFmtSigned(d['dayProfit']), valueColor: pdProfitColor(pdNum(d['dayProfit']))),
      const PdMetricItem('昨日收益', '--'),
      PdMetricItem('持有天数', holdDay is num ? '$holdDay' : '--'),
    ];
  }

  /// 阶段收益表 — uni-app updateStageGainList
  List<PdStageRow> get _stageRows {
    double? sumRecent(String key, int count, Map<String, dynamic> src) {
      final items = src[key];
      if (items is! List || items.isEmpty) return null;
      final values = items.take(count).map((e) => e is Map ? pdNum(e['value']) : null).whereType<double>().toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b);
    }

    PdStageRow makeRow(String label, double? fund, double? hs) {
      final excess = (fund != null && hs != null) ? fund - hs : null;
      return PdStageRow(
        date: label,
        change: fund == null ? '--' : pdFmtPercent(fund),
        hs300: hs == null ? '--' : pdFmtPercent(hs),
        excess: excess == null ? '--' : pdFmtPercent(excess),
        changeRaw: fund,
        hs300Raw: hs,
        excessRaw: excess,
      );
    }

    if (_activeStageTab == 'stage') {
      return [
        makeRow('近1月', sumRecent('month', 1, _fundIndicators), sumRecent('month', 1, _hsIndicators)),
        makeRow('近3月', sumRecent('month', 3, _fundIndicators), sumRecent('month', 3, _hsIndicators)),
        makeRow('近6月', sumRecent('month', 6, _fundIndicators), sumRecent('month', 6, _hsIndicators)),
        makeRow('近一年', sumRecent('month', 12, _fundIndicators), sumRecent('month', 12, _hsIndicators)),
      ];
    }
    final items = _fundIndicators[_activeStageTab];
    final hsItems = _hsIndicators[_activeStageTab];
    if (items is! List || items.isEmpty) {
      return [for (final l in ['近1月', '近3月', '近6月', '近一年']) makeRow(l, null, null)];
    }
    final hsList = hsItems is List ? hsItems : const [];
    return [
      for (var i = 0; i < items.length && i < 5; i++)
        makeRow(
          items[i] is Map ? '${items[i]['date'] ?? '--'}' : '--',
          items[i] is Map ? pdNum(items[i]['value']) : null,
          i < hsList.length && hsList[i] is Map ? pdNum(hsList[i]['value']) : null,
        ),
    ];
  }

  List<Map<String, String>> get _chartTabs => [
        {'label': '关联涨跌', 'value': 'sector'},
        {'label': '业绩走势', 'value': 'trend'},
        if (_hasPosition) {'label': '我的收益', 'value': 'profit'},
      ];

  String get _calendarSwitchLabel {
    if (_activeCalendarView == '日') return '$_calendarYear年$_calendarMonth月';
    if (_activeCalendarView == '月') return '$_calendarYear年';
    return '全部';
  }

  String get _calendarFooterLabel =>
      _activeCalendarView == '年' ? '$_calendarYear年' : '$_calendarMonth月';

  String get _calendarFooterProfitText {
    if (_showCalendarPercent) {
      if (_activeCalendarView == '年') return '--';
      final rate = _monthlyRateMap[_calendarMonth] ?? 0;
      if (rate == 0) return '--';
      return '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%';
    }
    if (_activeCalendarView == '年') return _yearlyProfitMap[_calendarYear] ?? '--';
    return _monthlyProfitMap[_calendarMonth] ?? '--';
  }

  // ===================== 底部操作 =====================

  List<PdActionItem> get _actions {
    final fav = _isFavorite
        ? const PdActionItem(label: '删自选', icon: AppIcons.addSuccess, iconSize: 18)
        : const PdActionItem(label: '加自选', icon: AppIcons.addAlt, iconSize: 18);
    final base = [fav, const PdActionItem(label: '修改持仓', icon: AppIcons.manualInput, iconSize: 18)];
    if (_hasPosition) {
      return [
        const PdActionItem(label: '交易记录', icon: AppIcons.record, iconSize: 22),
        ...base,
        const PdActionItem(label: '减仓', type: 'button', accent: 'sell'),
        const PdActionItem(label: '加仓', type: 'button', accent: 'buy'),
      ];
    }
    return [...base, const PdActionItem(label: '添加持有', type: 'button', accent: 'add')];
  }

  // ===================== 页面跳转（uni-app hendlbtnNavto）=====================

  int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  bool get _isAllDetailSelected => _selectedBookId == -1;

  String get _routeSymbolId => '${_info['symbolId'] ?? widget.symbolId}';

  /// uni-app resolveCurrentAssetId：按目标账本解析 assetId
  String _resolveCurrentAssetId(int? targetBookId) {
    final list = _assets;
    if (targetBookId == -1) {
      for (final item in list) {
        if (_asInt(item['assetId']) == -1 && _asInt(item['bookId']) == -1) {
          return '${item['assetId']}';
        }
      }
      return '';
    }
    if (targetBookId != null) {
      for (final item in list) {
        if (_asInt(item['bookId']) == targetBookId && item['assetId'] != null) {
          return '${item['assetId']}';
        }
      }
    }
    final routeAssetId = widget.assetId;
    if (routeAssetId != null) {
      if (targetBookId == null) return '$routeAssetId';
      for (final item in list) {
        if ('${item['assetId']}' == '$routeAssetId' && _asInt(item['bookId']) == targetBookId) {
          return '$routeAssetId';
        }
      }
    }
    if (list.isEmpty) return '';
    final detailAssetId = _positionDetail['assetId'];
    if (detailAssetId != null) return '$detailAssetId';
    for (final item in list) {
      if (_asInt(item['bookId']) != -1 && item['assetId'] != null) return '${item['assetId']}';
    }
    return '';
  }

  /// uni-app resolveTradingRecordTarget
  ({int? bookId, String assetId}) _resolveTradingRecordTarget() {
    final rows = _assets.where((item) {
      final bid = _asInt(item['bookId']);
      final aid = _asInt(item['assetId']);
      return bid != null && aid != null && bid != -1 && aid != -1;
    }).toList();
    Map<String, dynamic>? matchedAssetRow;
    final currentAssetId = widget.assetId;
    if (currentAssetId != null && currentAssetId != -1) {
      for (final r in rows) {
        if (_asInt(r['assetId']) == currentAssetId) {
          matchedAssetRow = r;
          break;
        }
      }
    }
    int? targetBookId;
    for (final c in [
      _selectedBookId,
      widget.bookId,
      _asInt(_positionDetail['bookId']),
      _asInt(matchedAssetRow?['bookId']),
    ]) {
      if (c != null && c != -1) {
        targetBookId = c;
        break;
      }
    }
    targetBookId ??= _asInt(matchedAssetRow?['bookId']) ??
        _asInt(_positionBooks.isNotEmpty ? _positionBooks.first['bookId'] : null);
    Map<String, dynamic>? matchedBookRow;
    for (final r in rows) {
      if (_asInt(r['bookId']) == targetBookId) {
        matchedBookRow = r;
        break;
      }
    }
    final assetId = matchedBookRow?['assetId'] ??
        matchedAssetRow?['assetId'] ??
        _resolveCurrentAssetId(targetBookId);
    return (bookId: targetBookId, assetId: '$assetId');
  }

  /// 交易记录 → /fund/trading-record
  void _goTradingRecord() {
    final target = _resolveTradingRecordTarget();
    context.push(Uri(path: '/fund/trading-record', queryParameters: {
      'shortName': _shortName,
      'symbolCode': _symbol,
      'symbolId': _routeSymbolId,
      'bookId': '${target.bookId ?? ''}',
      'assetId': target.assetId,
    }).toString());
  }

  /// uni-app buildTradePageUrl：加仓/减仓 → running-tab / gjs-bookkeeping
  void _goTradePage(String activeTab, int? targetBookId) {
    final path = _isPreciousMetal ? '/fund/gjs-bookkeeping' : '/fund/running-tab';
    context.push(Uri(path: path, queryParameters: {
      'activeTab': activeTab,
      'uniqueSymbol': _symbol,
      'shortName': _shortName,
      'symbolId': _routeSymbolId,
      'assetId': _resolveCurrentAssetId(targetBookId),
      'bookId': '${targetBookId ?? ''}',
      'assetType': '${_assetType ?? widget.assetType}',
    }).toString());
  }

  /// 加仓/减仓入口：全部账本且多账本时先弹账本选择
  void _handleTrade(String tradeType) {
    if (_positionBooks.length > 1 && _isAllDetailSelected) {
      _openTradeBookPicker(tradeType);
      return;
    }
    final int? targetBookId = _isAllDetailSelected
        ? (_asInt(_positionBooks.isNotEmpty ? _positionBooks.first['bookId'] : null) ??
            (widget.bookId == -1 ? null : widget.bookId))
        : _selectedBookId;
    _goTradePage(tradeType, targetBookId);
  }

  String _fmtEditAmount(dynamic v) {
    final n = v is num ? v : num.tryParse('$v');
    return n?.toStringAsFixed(2) ?? '';
  }

  /// uni-app fetchCurrentBookHoldingForEdit：编辑前拉当前账本持仓
  Future<({String marketValue, String holdProfit})> _fetchCurrentBookHoldingForEdit(
      int targetBookId, String symbolId) async {
    final res = await _api.get(ApiEndpoints.assetListV2, queryParameters: {'bookId': targetBookId});
    final data = _unwrap(res.data);
    List list = const [];
    if (data is Map && data['list'] is List) list = data['list'] as List;
    if (data is List) list = data;
    final items = list.whereType<Map<String, dynamic>>().toList();
    Map<String, dynamic>? matched;
    for (final item in items) {
      if ('${item['symbolId']}' == symbolId && _asInt(item['bookId']) == targetBookId) {
        matched = item;
        break;
      }
    }
    if (matched == null) {
      for (final item in items) {
        if ('${item['symbolId']}' == symbolId) {
          matched = item;
          break;
        }
      }
    }
    if (matched == null) throw StateError('current book holding not found');
    return (
      marketValue: _fmtEditAmount(matched['marketValue']),
      holdProfit: _fmtEditAmount(matched['holdProfit']),
    );
  }

  /// 修改持仓：贵金属 → gjs-holding-edit；全部账本 → add-records 选账本；单账本 → maddzx 编辑
  Future<void> _goEditHolding() async {
    final sid = _routeSymbolId;
    if (_isPreciousMetal) {
      final detail = _positionDetail;
      context.push(Uri(path: '/fund/gjs-holding-edit', queryParameters: {
        'assetId': _resolveCurrentAssetId(_selectedBookId),
        'bookId': _isAllDetailSelected
            ? '${detail['bookId'] ?? ''}'
            : '$_selectedBookId',
        'symbolId': sid,
        'uniqueSymbol': _symbol.isNotEmpty ? _symbol : '${detail['uniqueSymbol'] ?? ''}',
        'shortName': _shortName.isNotEmpty ? _shortName : '${detail['shortName'] ?? ''}',
        'holdQuantity': '${detail['holdQuantity'] ?? ''}',
        'holdCostAmount': '${detail['holdCostAmount'] ?? ''}',
        'comment': '${detail['comment'] ?? ''}',
      }).toString());
      return;
    }
    if (_isAllDetailSelected) {
      context.push(Uri(path: '/fund/upload/add-records', queryParameters: {
        'symbolId': sid,
        'shortName': _shortName,
        'fromDetails': '1',
      }).toString());
      return;
    }
    try {
      final payload = await _fetchCurrentBookHoldingForEdit(_selectedBookId, sid);
      if (!mounted) return;
      context.push(Uri(path: '/fund/upload/maddzx', queryParameters: {
        'uniqueSymbol': _symbol,
        'shortName': _shortName,
        'symbolId': sid,
        'fromDetails': '1',
        'mode': 'edit',
        'bookId': '$_selectedBookId',
        'marketValue': payload.marketValue,
        'holdProfit': payload.holdProfit,
      }).toString());
    } catch (_) {
      _todo('获取账本持仓失败，请重试');
    }
  }

  /// 添加持有 → add-records
  void _goAddHolding() {
    context.push(Uri(path: '/fund/upload/add-records', queryParameters: {
      'uniqueSymbol': _symbol,
      'shortName': _shortName,
      'symbolId': _routeSymbolId,
      'fromDetails': '1',
    }).toString());
  }

  void _handleAction(String label) {
    switch (label) {
      case '加自选':
        _openFavoriteBookPicker();
        break;
      case '删自选':
        _removeFavorite();
        break;
      case '减仓':
        _handleTrade('sell');
        break;
      case '加仓':
        _handleTrade('buy');
        break;
      case '交易记录':
        _goTradingRecord();
        break;
      case '修改持仓':
        _goEditHolding();
        break;
      case '添加持有':
        _goAddHolding();
        break;
    }
  }

  // ===================== Build =====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF6F6F8);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    final sectorValues = [for (final s in _sectorSeries) ...s.values.whereType<double>()];
    final maxPct = sectorValues.isEmpty ? '--' : '${sectorValues.reduce(max).toStringAsFixed(2)}%';
    final minV = sectorValues.isEmpty ? null : sectorValues.reduce(min);
    final minPct = minV == null ? '--' : '${minV >= 0 ? '+' : ''}${minV.toStringAsFixed(2)}%';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          _navbarScrolled && _shortName.isNotEmpty ? _shortName : '养基助手',
          style: AppTextStyles.cn(16, color: textColor, weight: FontWeight.w600),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final scrolled = n.metrics.pixels > 10;
          if (scrolled != _navbarScrolled) setState(() => _navbarScrolled = scrolled);
          return false;
        },
        child: GestureDetector(
          onTap: () {
            if (_bookDropdownOpen) setState(() => _bookDropdownOpen = false);
          },
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.upColor))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                  children: [
                    // ① 资产概览
                    PositionDetailsHeroCard(
                      isDark: isDark,
                      shortName: _shortName,
                      symbol: _symbol,
                      assetTypeLabel: _isPreciousMetal ? '贵金属' : (_fundTypeName.isNotEmpty ? _fundTypeName : '基金'),
                      summaryTop: _summaryTop,
                      showBookSelect: _bookTabs.length > 1,
                      selectedBookName: _bookTabs
                          .where((t) => t.bookId == _selectedBookId)
                          .map((t) => t.bookName)
                          .fold('全部', (a, b) => b),
                      bookDropdownOpen: _bookDropdownOpen,
                      bookTabs: _bookTabs,
                      selectedBookId: _selectedBookId,
                      onToggleBookDropdown: () => setState(() => _bookDropdownOpen = !_bookDropdownOpen),
                      onSelectBook: (tab) {
                        setState(() => _bookDropdownOpen = false);
                        _selectPositionDetail(tab.bookId == -1 ? null : tab.bookId);
                      },
                      positionMetrics: _positionMetrics,
                    ),
                    // ② 图表卡
                    Container(
                      margin: const EdgeInsets.only(top: 9), // 18rpx
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        PositionDetailsChartTabs(
                          tabs: _chartTabs,
                          activeTab: _activeChartTab,
                          isDark: isDark,
                          onChanged: (v) {
                            setState(() {
                              _activeChartTab = v;
                              _trendHoverIndex = -1;
                            });
                            if (v == 'trend' && _trendPoints.isEmpty) unawaited(_loadTrend(_activeTrendRange));
                          },
                        ),
                        if (_activeChartTab == 'sector')
                          PositionDetailsSectorPanel(
                            isDark: isDark,
                            seriesList: _sectorSeries,
                            tooltipTime: _sectorTooltipTime.isEmpty ? '--' : _sectorTooltipTime,
                            maxPct: maxPct,
                            minPct: minPct,
                            danmuOn: _isDanmuOn,
                            danmuRenderKey: _danmuRenderKey,
                            danmuItems: _visibleDanmu,
                            riseText: '看涨${_formatBarrageCount(_barrageRise)}',
                            fallText: '看跌${_formatBarrageCount(_barrageFall)}',
                            onToggleDanmu: _toggleDanmu,
                            onOpenDanmuPanel: _openDanmuPanel,
                            onVote: _voteBarrageTrend,
                            onReportDanmu: _reportDanmu,
                          )
                        else if (_activeChartTab == 'trend')
                          PositionDetailsTrendPanel(
                            isDark: isDark,
                            points: _trendPoints,
                            hoveredIndex: _trendHoverIndex,
                            onHover: (i) => setState(() => _trendHoverIndex = i),
                            rangeTabs: _trendRangeTabs,
                            activeRange: _activeTrendRange,
                            onRangeChange: (v) {
                              if (v == _activeTrendRange) return;
                              setState(() {
                                _activeTrendRange = v;
                                _trendHoverIndex = -1;
                              });
                              unawaited(_loadTrend(v));
                            },
                            loading: _trendLoading,
                          )
                        else
                          PositionDetailsProfitCalendar(
                            isDark: isDark,
                            showPercent: _showCalendarPercent,
                            onToggleMode: () => setState(() => _showCalendarPercent = !_showCalendarPercent),
                            views: const ['日', '月', '年'],
                            activeView: _activeCalendarView,
                            onViewChange: (v) => setState(() {
                              _activeCalendarView = v;
                              _selectedMonthCard = null;
                              _selectedYearCard = null;
                            }),
                            switchLabel: _calendarSwitchLabel,
                            onOpenMonthPicker: _openMonthPicker,
                            days: _calendarDays,
                            selectedDay: _selectedCalendarDay,
                            onDayTap: (d) {
                              if (d.day == null || d.type.isEmpty) return;
                              setState(() => _selectedCalendarDay = d.day);
                            },
                            monthCells: [
                              for (var m = 1; m <= 12; m++)
                                PdCalendarCell(m, _monthlyProfitMap[m] ?? '',
                                    isActive: (_monthlyProfitMap[m] ?? '').isNotEmpty && _selectedMonthCard == m),
                            ],
                            yearCells: [
                              for (final y in List.generate(6, (i) => DateTime.now().year - 5 + i))
                                PdCalendarCell(y, _yearlyProfitMap[y] ?? '',
                                    isActive: (_yearlyProfitMap[y] ?? '').isNotEmpty && _selectedYearCard == y),
                            ],
                            onMonthTap: (c) {
                              if (c.value.isEmpty) return;
                              setState(() => _selectedMonthCard = _selectedMonthCard == c.keyValue ? null : c.keyValue);
                            },
                            onYearTap: (c) {
                              if (c.value.isEmpty) return;
                              setState(() => _selectedYearCard = _selectedYearCard == c.keyValue ? null : c.keyValue);
                            },
                            footerLabel: _calendarFooterLabel,
                            footerProfitText: _calendarFooterProfitText,
                            summary: _calendarSummary,
                          ),
                      ]),
                    ),
                    // ③ 十大重仓股（关联涨跌 tab）
                    if (_activeChartTab == 'sector') PositionDetailsHeavyweight(isDark: isDark, list: _heavyweight),
                    // ④⑤ 收益/历史（业绩走势 tab）
                    if (_activeChartTab == 'trend') ...[
                      PositionDetailsStageCard(
                        isDark: isDark,
                        tabs: _stageTabs,
                        activeTab: _activeStageTab,
                        onTabChange: (v) => setState(() => _activeStageTab = v),
                        rows: _stageRows,
                        onMore: () => context.push('/fund/stage-revenue?symbolId=$_routeSymbolId'),
                      ),
                      PositionDetailsHistoryCard(
                        isDark: isDark,
                        title: _isPreciousMetal ? '历史克价' : '历史净值',
                        unitLabel: _isPreciousMetal ? '克价' : '单位净值',
                        rows: _historyRows,
                        onMore: () => context.push('/fund/listed-net-value?symbolId=$_routeSymbolId'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
      bottomNavigationBar: PositionDetailsBottomActions(isDark: isDark, actions: _actions, onTap: _handleAction),
    );
  }
}
