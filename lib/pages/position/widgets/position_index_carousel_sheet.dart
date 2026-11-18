import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../features/position/providers/position_provider.dart'
    show IndexCarouselItem;
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 指数详情半屏弹层 — 1:1 复刻 components/index-carousel-sheet.vue
/// 市场 tab（A股/港股/美股/全球/黄金）+ 行情头 + 分时图（自绘 CustomPainter，
/// 不引第三方图表库）+ 右侧指数列表 + 板块排行（A股/港股/美股）
class PositionIndexCarouselSheet extends StatefulWidget {
  final IndexCarouselItem item;
  final bool isDark;

  const PositionIndexCarouselSheet({
    super.key,
    required this.item,
    required this.isDark,
  });

  /// 打开半屏详情（对齐 sheet 的滑入动画 260ms + 遮罩 0.5）
  static Future<void> show(
    BuildContext context, {
    required IndexCarouselItem item,
    required bool isDark,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80000000),
      builder: (_) => PositionIndexCarouselSheet(item: item, isDark: isDark),
    );
  }

  @override
  State<PositionIndexCarouselSheet> createState() =>
      _PositionIndexCarouselSheetState();
}

/// 列表条目（1:1 normalizeListItem）
class _SymbolItem {
  final int symbolId;
  final String name;
  final String code;
  final double? price;
  final double? change;
  final double? rate;
  final double? amount;

  const _SymbolItem({
    required this.symbolId,
    required this.name,
    required this.code,
    this.price,
    this.change,
    this.rate,
    this.amount,
  });

  _SymbolItem copy() => _SymbolItem(
      symbolId: symbolId, name: name, code: code,
      price: price, change: change, rate: rate, amount: amount);

  static double? _num(dynamic v) {
    if (v == null || v == '') return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  factory _SymbolItem.fromJson(Map<String, dynamic> item, int index) {
    final latest = item['latestPrice'] is Map
        ? item['latestPrice'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final price = _num(latest['latestPrice'] ?? item['latestPrice'] ?? item['price'] ?? item['currentPrice']);
    final preClose = _num(latest['preClose'] ?? item['preClose']);
    final change = _num(latest['change'] ?? item['changeAmount'] ?? item['change']) ??
        ((price != null && preClose != null) ? price - preClose : null);
    final rate = _num(latest['changeRatio'] ?? latest['chgRate'] ?? item['changeRatio'] ?? item['chgRate'] ?? item['changeRate'] ?? item['riseRatio']) ??
        ((change != null && preClose != null && preClose != 0) ? change / preClose * 100 : null);
    return _SymbolItem(
      symbolId: (item['symbolId'] is num)
          ? (item['symbolId'] as num).toInt()
          : int.tryParse('${item['symbolId']}') ?? 0,
      name: (item['shortName'] ?? item['name'] ?? item['symbolName'] ?? '指数${index + 1}').toString(),
      code: (item['code'] ?? item['symbolCode'] ?? '').toString(),
      price: price,
      change: change,
      rate: rate,
    );
  }
}

/// 分时点（time=本地 epoch 秒）
class _Point {
  final int time;
  final double value;
  final double? averagePrice;
  final double? leadingPrice;
  final double volume;
  final double? previousClose;

  const _Point({
    required this.time,
    required this.value,
    this.averagePrice,
    this.leadingPrice,
    this.volume = 0,
    this.previousClose,
  });
}

/// 固定横轴（槽位 + 刻度）
class _FixedAxis {
  final List<int> slots;
  final List<({int index, String text, String align, bool grid})> ticks;
  const _FixedAxis(this.slots, this.ticks);
}

class _Sector {
  final int rank;
  final int symbolId;
  final String name;
  final double? rate;
  final bool down;
  final int? fundSectorId;
  const _Sector(this.rank, this.symbolId, this.name, this.rate, this.down,
      [this.fundSectorId]);
}

class _PositionIndexCarouselSheetState
    extends State<PositionIndexCarouselSheet> {
  final _api = ApiClient();

  static const _marketTabs = <(String, String)>[
    ('A股', 'CN'),
    ('港股', 'HK'),
    ('美股', 'US'),
    ('全球', 'GLOBAL'),
    ('黄金', 'GOLD'),
  ];
  static const _sectorMarkets = ['CN', 'HK', 'US'];

  String _activeMarket = 'CN';
  List<_SymbolItem> _marketList = [];
  final Map<String, List<_SymbolItem>> _marketCache = {};
  bool _listLoading = false;
  _SymbolItem? _selected;
  bool _chartLoading = false;
  List<_Point> _points = [];
  int _hoverIndex = -1;
  List<_Sector> _sectors = [];
  final Map<String, List<_Sector>> _sectorCache = {};
  int _sectorPage = 0;
  int _marketSeq = 0;
  int _quoteSeq = 0;
  int _chartSeq = 0;

  @override
  void initState() {
    super.initState();
    _activeMarket = _inferMarket(widget.item);
    _openMarket(_activeMarket, widget.item.symbolId);
    _loadSectorRanks(_activeMarket);
  }

  // ==================== 初始市场推断（1:1 inferMarket）====================
  String _inferMarket(IndexCarouselItem item) {
    final marketCode = item.marketCode.trim().toUpperCase();
    if (_marketTabs.any((t) => t.$2 == marketCode)) return marketCode;
    final code = item.code.trim().toUpperCase();
    if (['XAUCNY', 'XAGCNY', 'XPTCNY', 'WIKIWTI'].contains(code)) return 'GOLD';
    if (['HSI', 'HSCEI', 'HSTECH'].contains(code) || code.endsWith('.HK')) {
      return 'HK';
    }
    if (RegExp(r'^\d{6}$').hasMatch(code)) return 'CN';
    if (RegExp(r'^[A-Z]+$').hasMatch(code)) return 'US';
    return 'CN';
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] != null) {
      return data['data'];
    }
    return data;
  }

  // ==================== 市场列表 ====================

  Future<List<_SymbolItem>> _fetchMarketList(String market) async {
    if (market == 'GLOBAL') {
      // 全球固定 11 只（marketType=GL）；GL 未发版时回落热门指数口径
      try {
        final res = await _api.get(ApiEndpoints.symbolIndexes, queryParameters: {
          'MarketType': 'GL',
          'PageIndex': 1,
          'PageSize': 20,
        });
        final data = _unwrap(res.data);
        final list = data is List
            ? data
            : (data is Map ? (data['items'] ?? data['list']) : null);
        if (list is List && list.isNotEmpty) {
          var i = 0;
          return list
              .whereType<Map<String, dynamic>>()
              .map((e) => _SymbolItem.fromJson(e, i++))
              .toList();
        }
      } catch (_) {}
      final res = await _api.get(ApiEndpoints.marketHotIndex);
      final data = _unwrap(res.data);
      var i = 0;
      return (data is List ? data : const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => _SymbolItem.fromJson(e, i++))
          .toList();
    }
    if (market == 'GOLD') {
      final res = await _api.get(ApiEndpoints.goldEyeV1Quotes);
      final data = _unwrap(res.data);
      var i = 0;
      return (data is List ? data : const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => _SymbolItem.fromJson(e, i++))
          .toList();
    }
    final res = await _api.get(ApiEndpoints.symbolIndexes, queryParameters: {
      'MarketType': market,
      'PageIndex': 1,
      'PageSize': 12,
    });
    final data = _unwrap(res.data);
    final list = data is List
        ? data
        : (data is Map ? (data['items'] ?? data['list']) : null);
    var i = 0;
    return (list is List ? list : const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => _SymbolItem.fromJson(e, i++))
        .toList();
  }

  Future<void> _openMarket(String market, [int? preferSymbolId]) async {
    final seq = ++_marketSeq;
    _quoteSeq += 1;
    _chartSeq += 1;
    setState(() {
      _selected = null;
      _points = [];
    });
    if (_marketCache.containsKey(market)) {
      setState(() => _marketList = _marketCache[market]!);
      _ensureSelection(preferSymbolId);
      return;
    }
    setState(() {
      _marketList = [];
      _listLoading = true;
    });
    try {
      final list = (await _fetchMarketList(market))
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
      if (seq != _marketSeq || !mounted) return;
      _marketCache[market] = list;
      setState(() => _marketList = list);
      _ensureSelection(preferSymbolId);
    } catch (_) {
      if (seq != _marketSeq || !mounted) return;
      setState(() => _marketList = []);
    } finally {
      if (seq == _marketSeq && mounted) setState(() => _listLoading = false);
    }
  }

  void _switchMarket(String market) {
    if (market == _activeMarket) return;
    setState(() => _activeMarket = market);
    _openMarket(market);
    _loadSectorRanks(market);
  }

  void _ensureSelection(int? preferSymbolId) {
    final list = _marketList;
    if (list.isEmpty) {
      setState(() => _selected = null);
      return;
    }
    _SymbolItem? match;
    if (preferSymbolId != null) {
      for (final item in list) {
        if (item.symbolId == preferSymbolId) {
          match = item;
          break;
        }
      }
    }
    _selectSymbol(match ?? list.first);
  }

  // ==================== 选中指数与图表 ====================

  void _selectSymbol(_SymbolItem item) {
    setState(() => _selected = item.copy());
    if (_activeMarket == 'GOLD') {
      _quoteSeq += 1;
      if (item.symbolId <= 0) {
        _chartSeq += 1;
        setState(() {
          _points = [];
        });
        return;
      }
      unawaited(_loadGoldIntraday(item.symbolId));
      return;
    }
    if (item.symbolId <= 0) return;
    unawaited(_loadDetailQuote(item.symbolId));
    unawaited(_loadIntraday(item.symbolId));
  }

  /// 详情行情：成功后刷新头部，失败静默保留列表数据（1:1 loadDetailQuote）
  Future<void> _loadDetailQuote(int symbolId) async {
    final seq = ++_quoteSeq;
    try {
      final res =
          await _api.get('${ApiEndpoints.indexDetailQuote}/$symbolId/quote');
      if (seq != _quoteSeq || !mounted) return;
      final quote = _unwrap(res.data);
      if (quote is! Map) return;
      final current = _selected;
      if (current == null || current.symbolId != symbolId) return;
      setState(() {
        _selected = _SymbolItem(
          symbolId: current.symbolId,
          name: (quote['name'] ?? current.name).toString(),
          code: current.code,
          price: _SymbolItem._num(quote['price']) ?? current.price,
          change: _SymbolItem._num(quote['changeAmount']) ?? current.change,
          rate: _SymbolItem._num(quote['changePercent']) ?? current.rate,
          amount: _SymbolItem._num(quote['amount']) ?? current.amount,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadIntraday(int symbolId) async {
    final seq = ++_chartSeq;
    setState(() => _chartLoading = true);
    try {
      final res = await _api.get(
        '${ApiEndpoints.indexDetailIntraday}/$symbolId/intraday',
        queryParameters: {'days': 1},
      );
      if (seq != _chartSeq || !mounted) return;
      final data = _unwrap(res.data);
      final sessions = data is Map && data['sessions'] is List
          ? data['sessions'] as List
          : const [];
      setState(() {
        _points = _parseSessions(sessions);
      });
    } catch (_) {
      if (seq != _chartSeq || !mounted) return;
      setState(() {
        _points = [];
      });
    } finally {
      if (seq == _chartSeq && mounted) setState(() => _chartLoading = false);
    }
  }

  List<_Point> _parseSessions(List sessions) {
    final list = <_Point>[];
    for (final session in sessions) {
      if (session is! Map) continue;
      final prevClose = _SymbolItem._num(session['previousClose']);
      final points = session['points'] is List ? session['points'] as List : const [];
      for (final p in points) {
        if (p is! Map) continue;
        final time = _parseQuoteTime('${p['time'] ?? ''}');
        final value = _SymbolItem._num(p['price']);
        if (time <= 0 || value == null) continue;
        list.add(_Point(
          time: time,
          value: value,
          averagePrice: _SymbolItem._num(p['averagePrice']),
          leadingPrice: _SymbolItem._num(p['leadingPrice']),
          volume: _SymbolItem._num(p['volume']) ?? 0,
          previousClose: prevClose,
        ));
      }
    }
    // A 股/港股归并到固定槽位（1:1 snapAShare/snapHk）
    if (_activeMarket == 'CN') return _snapPoints(list, _snapAShareMinutes);
    if (_activeMarket == 'HK') return _snapPoints(list, _snapHkMinutes);
    return list;
  }

  /// 黄金分时：gold-eye 点列归并到分钟，只画最新一个自然日（1:1 loadGoldIntraday）
  Future<void> _loadGoldIntraday(int symbolId) async {
    final seq = ++_chartSeq;
    setState(() => _chartLoading = true);
    try {
      final res =
          await _api.get('${ApiEndpoints.goldEyeV1Intraday}/$symbolId');
      if (seq != _chartSeq || !mounted) return;
      final list = _unwrap(res.data);
      final minuteMap = <String, _Point>{};
      for (final item in (list is List ? list : const [])) {
        if (item is! Map) continue;
        final timeText = '${item['beijingTime'] ?? ''}';
        final value = _SymbolItem._num(item['price']);
        final time = _parseQuoteTime(timeText);
        if (time <= 0 || value == null || value <= 0) continue;
        // 分钟 key：yyyy-MM-ddTHH:mm
        final minuteKey = timeText.length >= 16
            ? timeText.substring(0, 16).replaceAll(' ', 'T')
            : timeText;
        minuteMap[minuteKey] = _Point(time: _parseQuoteTime('$minuteKey:00'), value: value);
      }
      final sorted = minuteMap.values.toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      // 只画最新一个自然日（北京时间 0 点起）
      final lastDay = sorted.isNotEmpty ? _localDateText(sorted.last.time) : '';
      final points =
          sorted.where((p) => _localDateText(p.time) == lastDay).toList();
      setState(() {
        _points = points;
      });
    } catch (_) {
      if (seq != _chartSeq || !mounted) return;
      setState(() {
        _points = [];
      });
    } finally {
      if (seq == _chartSeq && mounted) setState(() => _chartLoading = false);
    }
  }

  // ==================== 时间工具与槽位归并 ====================

  int _parseQuoteTime(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T\s]?(\d{2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(text);
    if (m == null) return 0;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    ).millisecondsSinceEpoch ~/
        1000;
  }

  String _localDateText(int unixSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// A 股槽位规则（1:1 snapAShareMinutes）
  int? _snapAShareMinutes(int minutes) {
    int hm(int h, int m) => h * 60 + m;
    if (minutes >= hm(9, 15) && minutes < hm(9, 30)) return hm(9, 30);
    if (minutes >= hm(9, 30) && minutes <= hm(11, 30)) return minutes;
    if (minutes == hm(13, 0)) return hm(11, 30);
    if (minutes > hm(13, 0) && minutes <= hm(15, 0)) return minutes;
    return null;
  }

  /// 港股槽位规则（1:1 snapHkMinutes）
  int? _snapHkMinutes(int minutes) {
    int hm(int h, int m) => h * 60 + m;
    if (minutes >= hm(9, 0) && minutes < hm(9, 30)) return hm(9, 30);
    if (minutes >= hm(9, 30) && minutes <= hm(12, 0)) return minutes;
    if (minutes >= hm(13, 0) && minutes <= hm(16, 0)) return minutes;
    if (minutes > hm(16, 0) && minutes <= hm(16, 10)) return hm(16, 0);
    return null;
  }

  /// 点归并：截到整分钟槽位，同槽位保留时间靠后的点（1:1 snapPoints）
  List<_Point> _snapPoints(
      List<_Point> points, int? Function(int) snapMinutes) {
    final bySlot = <int, _Point>{};
    for (final point in points) {
      final date = DateTime.fromMillisecondsSinceEpoch(point.time * 1000);
      final minutes = snapMinutes(date.hour * 60 + date.minute);
      if (minutes == null) continue;
      final slot = DateTime(date.year, date.month, date.day,
              minutes ~/ 60, minutes % 60)
          .millisecondsSinceEpoch ~/
          1000;
      final prev = bySlot[slot];
      if (prev == null || point.time >= prev.time) {
        bySlot[slot] = _Point(
          time: slot,
          value: point.value,
          averagePrice: point.averagePrice,
          leadingPrice: point.leadingPrice,
          volume: point.volume,
          previousClose: point.previousClose,
        );
      }
    }
    final result = bySlot.values.toList()..sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  // ==================== 固定横轴 ====================

  List<int> _slotsForRange(String tradeDate, int startMin, int endMin) {
    final parts = tradeDate.split('-').map(int.parse).toList();
    return [
      for (var t = startMin; t <= endMin; t++)
        DateTime(parts[0], parts[1], parts[2], t ~/ 60, t % 60)
            .millisecondsSinceEpoch ~/
            1000,
    ];
  }

  bool _isUsDst(String tradeDate) {
    final parts = tradeDate.split('-').map(int.parse).toList();
    final y = parts[0], m = parts[1], d = parts[2];
    int nthSunday(int month, int n) =>
        1 + ((7 - DateTime(y, month, 1).weekday) % 7) + (n - 1) * 7;
    final value = m * 100 + d;
    return value >= 300 + nthSunday(3, 2) && value < 1100 + nthSunday(11, 1);
  }

  _FixedAxis? _buildFixedAxis() {
    final points = _points;
    if (points.isEmpty) return null;
    final tradeDates = points.map((p) => _localDateText(p.time)).toSet();
    final slotSet = <int>{};
    List<int> slots;
    List<({int index, String text, String align, bool grid})> ticks;
    switch (_activeMarket) {
      case 'CN':
        if (tradeDates.length != 1) return null;
        final date = tradeDates.first;
        slots = [
          ..._slotsForRange(date, 9 * 60 + 30, 11 * 60 + 30),
          ..._slotsForRange(date, 13 * 60 + 1, 15 * 60),
        ];
        final last = slots.length - 1;
        ticks = [
          (index: 0, text: '9:30', align: 'left', grid: false),
          (index: last ~/ 4, text: '', align: '', grid: true),
          (index: last ~/ 2, text: '11:30', align: '', grid: true),
          (index: last * 3 ~/ 4, text: '', align: '', grid: true),
          (index: last, text: '15:00', align: 'right', grid: false),
        ];
      case 'HK':
        if (tradeDates.length != 1) return null;
        final date = tradeDates.first;
        slots = [
          ..._slotsForRange(date, 9 * 60 + 30, 12 * 60),
          ..._slotsForRange(date, 13 * 60, 16 * 60),
        ];
        final noon = 12 * 60 - (9 * 60 + 30);
        final last = slots.length - 1;
        ticks = [
          (index: 0, text: '9:30', align: 'left', grid: false),
          (index: noon ~/ 2, text: '', align: '', grid: true),
          (index: noon, text: '12:00', align: '', grid: true),
          (index: (noon + last) ~/ 2, text: '', align: '', grid: true),
          (index: last, text: '16:00', align: 'right', grid: false),
        ];
      case 'US':
        final sessionDate =
            tradeDates.isNotEmpty ? tradeDates.first : '';
        if (sessionDate.isEmpty) return null;
        final dst = _isUsDst(sessionDate);
        final open = dst ? 21 * 60 + 30 : 22 * 60 + 30;
        slots = _slotsForRange(sessionDate, open, open + 390);
        final last = slots.length - 1;
        String label(int minutes) =>
            '${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
        final close = open + 390;
        ticks = [
          (index: 0, text: label(open), align: 'left', grid: false),
          (index: last ~/ 4, text: '', align: '', grid: true),
          (index: last ~/ 2, text: '00:00', align: '', grid: true),
          (index: last * 3 ~/ 4, text: '', align: '', grid: true),
          (index: last, text: label(close), align: 'right', grid: false),
        ];
      case 'GOLD':
        if (tradeDates.length != 1) return null;
        final date = tradeDates.first;
        slots = _slotsForRange(date, 0, 24 * 60);
        final last = slots.length - 1;
        ticks = [
          (index: 0, text: '00:00', align: 'left', grid: false),
          (index: last ~/ 4, text: '', align: '', grid: true),
          (index: last ~/ 2, text: '12:00', align: '', grid: true),
          (index: last * 3 ~/ 4, text: '', align: '', grid: true),
          (index: last, text: '24:00', align: 'right', grid: false),
        ];
      default:
        // 全球：自适应轴（未收录的指数无固定槽位表，按源码回退自适应）
        return null;
    }
    slotSet.addAll(slots);
    // 任何一个点落不进槽位，固定横轴整体回退自适应（1:1）
    if (!points.every((p) => slotSet.contains(p.time))) return null;
    return _FixedAxis(slots, ticks);
  }

  /// 全球自适应轴：休市缺口按分钟补 whitespace（1:1 padWhitespacePoints）
  List<_Point?> _chartLinePoints() {
    if (_activeMarket != 'GLOBAL' || _buildFixedAxis() != null) {
      return List<_Point?>.from(_points);
    }
    final points = _points;
    if (points.length < 2) return List<_Point?>.from(points);
    final step = math.max(60, points[1].time - points[0].time);
    final dense = <_Point?>[];
    var expected = points[0].time;
    for (final point in points) {
      while (expected < point.time) {
        dense.add(null);
        expected += step;
      }
      dense.add(point);
      expected = point.time + step;
    }
    return dense;
  }

  // ==================== 板块排行 ====================

  Future<void> _loadSectorRanks(String market) async {
    if (!_sectorMarkets.contains(market)) return;
    if (_sectorCache.containsKey(market)) {
      setState(() => _sectors = _sectorCache[market]!);
      return;
    }
    try {
      final res = await _api.get(
        ApiEndpoints.marketFundSectorRanking,
        queryParameters: {'PageIndex': 1, 'PageSize': 18, 'market': market},
      );
      final data = _unwrap(res.data);
      final list = data is Map && data['items'] is List
          ? data['items'] as List
          : (data is List ? data : const []);
      final mapped = <_Sector>[];
      var index = 0;
      for (final item in list.take(18)) {
        if (item is! Map) continue;
        final latest = item['latestPrice'] is Map
            ? item['latestPrice'] as Map<String, dynamic>
            : const <String, dynamic>{};
        final rate = _SymbolItem._num(
            latest['chgRate'] ?? item['chgRate'] ?? item['changeRatio']);
        mapped.add(_Sector(
          index + 1,
          item['symbolId'] is num ? (item['symbolId'] as num).toInt() : 0,
          (item['shortName'] ?? item['name'] ?? item['symbolName'] ?? '板块${index + 1}')
              .toString(),
          rate,
          (rate ?? 0) < 0,
          item['fundSectorId'] is num ? (item['fundSectorId'] as num).toInt() : null,
        ));
        index++;
      }
      _sectorCache[market] = mapped;
      if (!mounted) return;
      if (_activeMarket == market) setState(() => _sectors = mapped);
    } catch (_) {
      if (!mounted) return;
      if (_activeMarket == market) setState(() => _sectors = []);
    }
  }

  // ==================== 展示辅助 ====================

  double? get _trendValue =>
      _selected?.change ?? _selected?.rate;
  int? get _trend {
    final v = _trendValue;
    if (v == null) return null;
    return v >= 0 ? 1 : -1;
  }

  Color get _lineColor =>
      (_trend ?? 1) >= 0 ? const Color(0xFFF5465C) : const Color(0xFF20B083);

  Color _trendColorOf(double? rate) {
    if (rate == null) return const Color(0xFF5A5F6A);
    return rate >= 0 ? _lineColor : const Color(0xFF20B083);
  }

  String _fmtPrice(double? v) => v == null ? '--' : v.toStringAsFixed(2);
  String _fmtChange(double? v) =>
      v == null ? '--' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
  String _fmtRate(double? v) =>
      v == null ? '--' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  String _fmtAmount(double? v) {
    if (v == null) return '';
    final abs = v.abs();
    if (abs >= 1e8) return '${(v / 1e8).toStringAsFixed(2)}亿';
    if (abs >= 1e4) return '${(v / 1e4).toStringAsFixed(2)}万';
    return '$v';
  }

  String _fmtVolume(double? v) {
    if (v == null) return '--';
    if (v.abs() >= 1e8) return '${(v / 1e8).toStringAsFixed(2)}亿手';
    if (v.abs() >= 1e4) return '${(v / 1e4).toStringAsFixed(2)}万手';
    return '${v.round()}手';
  }

  bool get _showSectorSection =>
      _sectorMarkets.contains(_activeMarket) && _sectors.isNotEmpty;

  String? get _sectorBadge {
    if (_activeMarket == 'HK') return 'HK';
    if (_activeMarket == 'US') return 'US';
    return null;
  }

  /// 叠加线：有均价用 averagePrice，否则 leadingPrice（1:1 overlayLineKey）
  bool get _useAveragePrice =>
      _points.any((p) => p.averagePrice != null && p.averagePrice! > 0);

  List<(int, double)> get _overlayLine {
    final useAvg = _useAveragePrice;
    return [
      for (final p in _points)
        if ((useAvg ? p.averagePrice : p.leadingPrice) != null &&
            (useAvg ? p.averagePrice! : p.leadingPrice!) > 0)
          (p.time, useAvg ? p.averagePrice! : p.leadingPrice!),
    ];
  }

  double? get _overlayValue {
    final line = _overlayLine;
    if (line.isEmpty) return null;
    if (_hoverIndex >= 0 && _hoverIndex < _points.length) {
      final p = _points[_hoverIndex];
      final v = _useAveragePrice ? p.averagePrice : p.leadingPrice;
      if (v != null && v > 0) return v;
    }
    return line.last.$2;
  }

  /// 图例取值：十字光标命中点，否则最后一点（1:1 cursorPoint）
  ({double value, double? volume, double? rate})? get _cursorPoint {
    final points = _points;
    if (points.isEmpty) return null;
    final index = (_hoverIndex >= 0 && _hoverIndex < points.length)
        ? _hoverIndex
        : points.length - 1;
    final p = points[index];
    final prevClose = p.previousClose;
    final rate = (prevClose != null && prevClose > 0)
        ? (p.value - prevClose) / prevClose * 100
        : _selected?.rate;
    return (value: p.value, volume: p.volume, rate: rate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final panelBg = isDark ? const Color(0xFF202125) : Colors.white;
    final tabColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF5A5F6A);
    final activeTabColor = isDark ? const Color(0xFFFF6B74) : const Color(0xFFE15665);
    final nameColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1F2430);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8A8F99);
    final lineColor = _lineColor;
    final trendColor = _trend == null
        ? nameColor
        : (_trend! >= 0 ? (isDark ? const Color(0xFFFF6B74) : const Color(0xFFE15665)) : const Color(0xFF20B083));
    final cursor = _cursorPoint;
    final cursorTrendColor = cursor?.rate == null
        ? subColor
        : (cursor!.rate! >= 0 ? lineColor : const Color(0xFF20B083));

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12.sx)), // 24rpx
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          // 短屏设备上内容超过 90vh 时可滚动（源码 max-height:90vh + 内部 scroll）
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ===== header：市场 tabs + 设置 + 关闭 =====
            SizedBox(
              height: 50.sx, // 100rpx
              child: Row(children: [
                Expanded(
                  child: Row(children: [
                    for (final tab in _marketTabs)
                      GestureDetector(
                        onTap: () => _switchMarket(tab.$2),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 9.sx, vertical: 6.sx), // 12rpx 18rpx
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(
                              tab.$1,
                              style: AppTextStyles.cn(
                                16.sx, // 32rpx
                                color: _activeMarket == tab.$2 ? activeTabColor : tabColor,
                                weight: _activeMarket == tab.$2
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 2.sx),
                            Container(
                              width: 16.sx, // 32rpx
                              height: 3.sx, // 6rpx
                              decoration: BoxDecoration(
                                color: _activeMarket == tab.$2
                                    ? activeTabColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(1.5.sx), // 3rpx
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
                // 齿轮 → 指数设置（占位页）
                GestureDetector(
                  onTap: () => context.push('/position/index-settings'),
                  child: SizedBox(
                    width: 28.sx, // 56rpx
                    height: 28.sx,
                    child: Icon(Icons.settings_outlined, size: 20, color: subColor),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 28.sx,
                    height: 28.sx,
                    child: Icon(Icons.close, size: 20, color: subColor),
                  ),
                ),
              ]),
            ),
            // ===== body：左行情+图表 / 右指数列表 =====
            SizedBox(
              height: 356.sx, // name(15) + quote(28) + chart(280) + paddings ≈ 712rpx
              child: Stack(children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12.sx, 8.sx, 82.sx, 8.sx), // 右侧留 164rpx
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _selected?.name ?? '--',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cn(15.sx,
                          color: nameColor, weight: FontWeight.w600, height: 1),
                    ),
                    SizedBox(height: 4.sx), // margin-top 8rpx
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _fmtPrice(_selected?.price),
                            style: AppTextStyles.num(20.sx,
                                color: trendColor, weight: FontWeight.w700), // 40rpx
                          ),
                          SizedBox(width: 8.sx), // margin-right 16rpx
                          Text(_fmtChange(_selected?.change),
                              style: AppTextStyles.num(12.sx, color: trendColor)),
                          SizedBox(width: 8.sx),
                          Text(_fmtRate(_selected?.rate),
                              style: AppTextStyles.num(12.sx, color: trendColor)),
                          if (_selected?.amount != null) ...[
                            SizedBox(width: 8.sx),
                            Text(_fmtAmount(_selected!.amount),
                                style: AppTextStyles.num(12.sx, color: subColor)),
                          ],
                        ]),
                    SizedBox(height: 8.sx), // margin-top 16rpx
                    // ===== 图表区（固定 560rpx） =====
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2B2D33)
                                  : const Color(0xFFF0F3FA),
                              width: 1),
                        ),
                        child: _points.isEmpty
                            ? Center(
                                child: Text(
                                  _chartLoading ? '加载中...' : '暂无图表数据',
                                  style: AppTextStyles.cn(12.sx, color: subColor),
                                ),
                              )
                            : _IntradayChart(
                                points: _chartLinePoints(),
                                rawPoints: _points,
                                axis: _buildFixedAxis(),
                                lineColor: lineColor,
                                overlayLine: _overlayLine,
                                overlayLabel:
                                    _useAveragePrice ? '均价' : '领先',
                                overlayValue: _overlayValue,
                                overlayColor: const Color(0xFFF5A623),
                                latestPrice: _selected?.price,
                                cursor: cursor,
                                hoverIndex: _hoverIndex,
                                onHover: (i) => setState(() => _hoverIndex = i),
                                isDark: isDark,
                                volumeText: cursor?.volume == null
                                    ? null
                                    : _fmtVolume(cursor!.volume),
                                cursorRateText: cursor?.rate == null
                                    ? '--'
                                    : _fmtRate(cursor!.rate),
                                cursorTrendColor: cursorTrendColor,
                                onChartTap: _goSymbolDetails,
                              ),
                      ),
                    ),
                  ]),
                ),
                // ===== 右侧指数列表（148rpx 绝对定位滚动） =====
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 74.sx, // 148rpx
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.sx, right: 8.sx),
                    child: _marketList.isEmpty
                        ? Center(
                            child: Text(
                              _listLoading ? '加载中...' : '暂无数据',
                              style: AppTextStyles.cn(12.sx, color: subColor),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _marketList.length,
                            itemBuilder: (_, i) {
                              final item = _marketList[i];
                              final selected = _isSelected(item);
                              return GestureDetector(
                                onTap: () => _selectSymbol(item),
                                child: Container(
                                  height: 40.sx, // 80rpx
                                  margin: EdgeInsets.only(bottom: 5.sx), // 10rpx
                                  padding: EdgeInsets.symmetric(horizontal: 3.sx),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFE15665)
                                        : (isDark
                                            ? const Color(0xFF2B2D33)
                                            : const Color(0xFFF5F6F8)),
                                    borderRadius: BorderRadius.circular(4.sx), // 8rpx
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.cn(
                                          12.sx, // 24rpx
                                          color: selected
                                              ? Colors.white
                                              : (isDark
                                                  ? const Color(0xFFA7ADB8)
                                                  : const Color(0xFF5A5F6A)),
                                        ),
                                      ),
                                      SizedBox(height: 1.sx),
                                      Text(
                                        _fmtRate(item.rate),
                                        style: AppTextStyles.num(
                                          11.sx, // 22rpx
                                          color: selected
                                              ? Colors.white
                                              : _trendColorOf(item.rate),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ]),
            ),
            // ===== 板块排行（A股/港股/美股；其他市场保留高度防抖动） =====
            _buildSectors(isDark, nameColor, subColor),
          ]),
          ),
        ),
      ),
    );
  }

  bool _isSelected(_SymbolItem item) {
    final current = _selected;
    if (current == null) return false;
    if (item.symbolId > 0 && current.symbolId > 0) {
      return item.symbolId == current.symbolId;
    }
    return item.code == current.code && item.name == current.name;
  }

  /// 板块排行区：标题 + 板块总览 + 两行三列分页网格 + 分页点
  Widget _buildSectors(bool isDark, Color nameColor, Color subColor) {
    final visible = _showSectorSection;
    final pages = <List<_Sector>>[
      for (var i = 0; i < _sectors.length; i += 6) _sectors.sublist(i, math.min(i + 6, _sectors.length)),
    ];
    return Opacity(
      opacity: visible ? 1 : 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.sx, 8.sx, 12.sx, 12.sx), // 16rpx 24rpx 24rpx
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('板块排行',
                style: AppTextStyles.cn(16.sx,
                    color: nameColor, weight: FontWeight.w600)), // 32rpx
            GestureDetector(
              onTap: () => context.push('/plate-data'),
              child: Row(children: [
                Text('板块总览', style: AppTextStyles.cn(12.sx, color: subColor)),
                Icon(Icons.chevron_right, size: 12, color: subColor),
              ]),
            ),
          ]),
          SizedBox(height: 10.sx), // margin-top 20rpx
          SizedBox(
            height: 124.sx, // 248rpx（118rpx×2 行 + 12rpx 行距）
            child: PageView.builder(
              onPageChanged: (i) => setState(() => _sectorPage = i),
              itemCount: pages.length,
              itemBuilder: (_, pageIndex) {
                final page = pages[pageIndex];
                return Wrap(
                  spacing: 6.sx, // gap 12rpx
                  runSpacing: 6.sx,
                  children: [
                    for (final sector in page)
                      GestureDetector(
                        onTap: () => context.push(Uri(
                          path: '/market/sector-details',
                          queryParameters: {
                            'symbolId': '${sector.symbolId}',
                            'name': sector.name,
                            'market': _activeMarket,
                          },
                        ).toString()),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 24.sx - 12.sx) / 3,
                          height: 59.sx, // 118rpx
                          decoration: BoxDecoration(
                            color: sector.down
                                ? (isDark
                                    ? const Color(0x1F2ECF9A)
                                    : const Color(0xFFEDF8F4))
                                : (isDark
                                    ? const Color(0x1FFF6B74)
                                    : const Color(0xFFFDF1F2)),
                            borderRadius: BorderRadius.circular(4.sx), // 8rpx
                          ),
                          child: Stack(children: [
                            if (_sectorBadge != null)
                              Positioned(
                                top: 3.sx,
                                right: 3.sx,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4.sx, vertical: 1.sx),
                                  decoration: BoxDecoration(
                                    color: const Color(0x268A8F99),
                                    borderRadius: BorderRadius.circular(3.sx), // 6rpx
                                  ),
                                  child: Text(
                                    _sectorBadge!,
                                    style: AppTextStyles.cn(9.sx,
                                        color: const Color(0xFF8A8F99)), // 18rpx
                                  ),
                                ),
                              ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    sector.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.cn(13.sx, color: nameColor), // 26rpx
                                  ),
                                  SizedBox(height: 3.sx),
                                  Text(
                                    _fmtRate(sector.rate),
                                    style: AppTextStyles.num(
                                      15.sx, // 30rpx
                                      color: sector.down
                                          ? const Color(0xFF20B083)
                                          : (isDark
                                              ? const Color(0xFFFF6B74)
                                              : const Color(0xFFE15665)),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (pages.length > 1)
            Padding(
              padding: EdgeInsets.only(top: 6.sx), // margin-top 12rpx
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < pages.length; i++)
                  Container(
                    width: i == _sectorPage ? 12.sx : 5.sx, // active 24rpx / 10rpx
                    height: 5.sx, // 10rpx
                    margin: EdgeInsets.symmetric(horizontal: 2.sx),
                    decoration: BoxDecoration(
                      color: i == _sectorPage
                          ? (isDark
                              ? const Color(0xFF8F96A3)
                              : const Color(0xFFA7ADB8))
                          : (isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFD9DDE3)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  /// 点按图表跳指数详情（黄金/商品不跳，1:1 goSymbolDetails）
  void _goSymbolDetails() {
    final item = _selected;
    if (item == null || item.symbolId <= 0 || _activeMarket == 'GOLD') return;
    context.push(Uri(path: '/market/stock-detail', queryParameters: {
      'symbolId': '${item.symbolId}',
      'name': item.name,
      'code': item.code,
    }).toString());
  }
}

/// 分时图（自绘 CustomPainter）：主折线 + 面积 + 均价/领先线 + 成交量副图 +
/// 价格刻度/时间刻度/网格/最新价 pill + 触摸十字线
class _IntradayChart extends StatelessWidget {
  final List<_Point?> points; // 画线用（全球自适应已补 whitespace）
  final List<_Point> rawPoints; // 图例/光标取值用（未补点）
  final _FixedAxis? axis;
  final Color lineColor;
  final List<(int, double)> overlayLine;
  final String overlayLabel;
  final double? overlayValue;
  final Color overlayColor;
  final double? latestPrice;
  final ({double value, double? volume, double? rate})? cursor;
  final int hoverIndex;
  final ValueChanged<int> onHover;
  final bool isDark;
  final String? volumeText;
  final String cursorRateText;
  final Color cursorTrendColor;
  final VoidCallback onChartTap;

  const _IntradayChart({
    required this.points,
    required this.rawPoints,
    required this.axis,
    required this.lineColor,
    required this.overlayLine,
    required this.overlayLabel,
    required this.overlayValue,
    required this.overlayColor,
    required this.latestPrice,
    required this.cursor,
    required this.hoverIndex,
    required this.onHover,
    required this.isDark,
    required this.volumeText,
    required this.cursorRateText,
    required this.cursorTrendColor,
    required this.onChartTap,
  });

  static const _legendBand = 22.0; // LEGEND_BAND_PX
  static const _timeAxis = 28.0;
  static const _subPane = 76.0; // CHART_SUB_PANE_PX
  static const _rightBlank = 36.0; // CHART_RIGHT_BLANK_PX

  @override
  Widget build(BuildContext context) {
    final hasVolume = rawPoints.any((p) => p.volume > 0);
    final legendBg = isDark ? const Color(0xFF202125) : Colors.white;
    final legendBorder = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F3FA);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _updateHover(d.localPosition, context),
      onHorizontalDragUpdate: (d) => _updateHover(d.localPosition, context),
      onTap: onChartTap,
      child: Column(children: [
        // 主图图例条（通栏、上下细线、22px）
        Container(
          height: _legendBand,
          padding: const EdgeInsets.only(left: 4, right: 10),
          decoration: BoxDecoration(
            color: legendBg,
            border: Border(bottom: BorderSide(color: legendBorder, width: 1)),
          ),
          child: Row(children: [
            if (overlayLine.isNotEmpty) ...[
              Text(
                '$overlayLabel:${overlayValue == null ? '--' : overlayValue!.toStringAsFixed(2)}',
                style: AppTextStyles.num(10, color: overlayColor),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              '最新:${cursor == null ? '--' : cursor!.value.toStringAsFixed(2)} $cursorRateText',
              style: AppTextStyles.num(10, color: cursorTrendColor),
            ),
          ]),
        ),
        // 图表本体（CustomPainter）
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ChartPainter(
                  points: points,
                  rawPoints: rawPoints,
                  axis: axis,
                  lineColor: lineColor,
                  overlayLine: overlayLine,
                  overlayColor: overlayColor,
                  latestPrice: latestPrice,
                  hoverIndex: hoverIndex,
                  hasVolume: hasVolume,
                  isDark: isDark,
                  timeAxis: _timeAxis,
                  subPane: hasVolume ? _subPane : 0,
                  rightBlank: _rightBlank,
                ),
              );
            },
          ),
        ),
        // 成交量副图图例条（钉在副图顶部，上移 1px 盖 pane 分隔线）
        if (hasVolume)
          Container(
            height: _legendBand,
            margin: const EdgeInsets.only(top: -1),
            padding: const EdgeInsets.only(left: 4, right: 10),
            decoration: BoxDecoration(
              color: legendBg,
              border: Border(
                top: BorderSide(color: legendBorder, width: 1),
                bottom: BorderSide(color: legendBorder, width: 1),
              ),
            ),
            child: Row(children: [
              Text(
                '成交量:${volumeText ?? '--'}',
                style: AppTextStyles.num(10, color: cursorTrendColor),
              ),
            ]),
          ),
      ]),
    );
  }

  void _updateHover(Offset pos, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || rawPoints.isEmpty) return;
    // 用时间换算索引：与 painter 同一套几何（简化：按 x 比例映射到槽位）
    final width = box.size.width;
    final count = axis?.slots.length ?? rawPoints.length;
    if (count <= 1) return;
    final ratio = (pos.dx / (width - _rightBlank)).clamp(0.0, 1.0);
    final index = (ratio * (rawPoints.length - 1)).round().clamp(0, rawPoints.length - 1);
    onHover(index);
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Point?> points;
  final List<_Point> rawPoints;
  final _FixedAxis? axis;
  final Color lineColor;
  final List<(int, double)> overlayLine;
  final Color overlayColor;
  final double? latestPrice;
  final int hoverIndex;
  final bool hasVolume;
  final bool isDark;
  final double timeAxis;
  final double subPane;
  final double rightBlank;

  const _ChartPainter({
    required this.points,
    required this.rawPoints,
    required this.axis,
    required this.lineColor,
    required this.overlayLine,
    required this.overlayColor,
    required this.latestPrice,
    required this.hoverIndex,
    required this.hasVolume,
    required this.isDark,
    required this.timeAxis,
    required this.subPane,
    required this.rightBlank,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F3FA);
    final textColor = isDark ? const Color(0xFF8A93A6) : const Color(0xFF8A93A6);
    final plotW = size.width - rightBlank;
    final mainH = size.height - timeAxis - subPane;
    if (mainH <= 0 || points.isEmpty) return;

    // ===== 价格范围（主线 + 叠加线并集） =====
    final values = <double>[
      for (final p in points)
        if (p != null) p.value,
      for (final e in overlayLine) e.$2,
    ];
    if (values.isEmpty) return;
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if ((maxV - minV).abs() < 1e-9) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.08;
    minV -= pad;
    maxV += pad;

    final count = axis?.slots.length ?? points.length;
    double xAt(int i) => count <= 1 ? 0 : i / (count - 1) * plotW;
    double yAt(double v) => mainH - (v - minV) / (maxV - minV) * mainH;

    // ===== 横网格线 + 价格刻度（右缘，5 档） =====
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final tickCount = 5;
    for (var t = 0; t < tickCount; t++) {
      final v = maxV - (maxV - minV) / (tickCount - 1) * t;
      final y = yAt(v);
      canvas.drawLine(Offset(0, y), Offset(plotW, y), gridPaint);
      _drawText(
        canvas,
        v.toStringAsFixed(2),
        Offset(plotW + 2, y - 12),
        TextStyle(color: textColor, fontSize: 11, fontFamily: 'DIN'),
      );
    }

    // ===== 竖网格线 + 时间刻度 =====
    if (axis != null) {
      for (final tick in axis!.ticks) {
        final x = xAt(tick.index);
        if (tick.grid) {
          canvas.drawLine(Offset(x, 0), Offset(x, mainH), gridPaint);
        }
        if (tick.text.isNotEmpty) {
          double dx = x;
          final tp = _layoutText(
            tick.text,
            TextStyle(color: textColor, fontSize: 11, fontFamily: 'DIN'),
          );
          if (tick.align == 'left') {
            dx = x;
          } else if (tick.align == 'right') {
            dx = x - tp.width;
          } else {
            dx = x - tp.width / 2;
          }
          tp.paint(canvas, Offset(dx.clamp(0.0, size.width - tp.width), mainH + 7));
        }
      }
    } else if (rawPoints.isNotEmpty) {
      // 自适应轴：首/中/尾三个时间刻度
      final idxs = [0, (rawPoints.length - 1) ~/ 2, rawPoints.length - 1];
      for (final i in idxs) {
        final p = rawPoints[i];
        final x = xAt(i);
        final tp = _layoutText(
          _hhmm(p.time),
          TextStyle(color: textColor, fontSize: 11, fontFamily: 'DIN'),
        );
        final dx = i == 0
            ? x
            : (i == rawPoints.length - 1 ? x - tp.width : x - tp.width / 2);
        tp.paint(canvas, Offset(dx.clamp(0.0, size.width - tp.width), mainH + 7));
      }
    }

    // ===== 面积 + 主折线 =====
    final linePath = Path();
    final areaPath = Path();
    var started = false;
    double? lastX;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p == null) continue;
      final x = xAt(i), y = yAt(p.value);
      if (!started) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, mainH);
        areaPath.lineTo(x, y);
        started = true;
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
      lastX = x;
    }
    if (started && lastX != null) {
      areaPath.lineTo(lastX, mainH);
      areaPath.close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lineColor.withValues(alpha: 0.16), lineColor.withValues(alpha: 0)],
          ).createShader(Rect.fromLTRB(0, 0, plotW, mainH)),
      );
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    // ===== 均价/领先线 =====
    if (overlayLine.isNotEmpty) {
      // 叠加线按时间映射到槽位下标
      final timeToIndex = <int, int>{};
      for (var i = 0; i < rawPoints.length; i++) {
        timeToIndex[rawPoints[i].time] = i;
      }
      final path = Path();
      var started2 = false;
      for (final entry in overlayLine) {
        final i = timeToIndex[entry.$1];
        if (i == null) continue;
        final x = xAt(i), y = yAt(entry.$2);
        if (!started2) {
          path.moveTo(x, y);
          started2 = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = overlayColor
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    // ===== 最新价虚线 + pill =====
    if (latestPrice != null && latestPrice! > 0) {
      final y = yAt(latestPrice!);
      final dashPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var x = 0.0; x < plotW; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, plotW), y), dashPaint);
      }
      // pill
      final tp = _layoutText(
        latestPrice!.toStringAsFixed(2),
        const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'DIN'),
      );
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(plotW + 3, y - tp.height / 2 - 3, tp.width + 14, tp.height + 6),
        const Radius.circular(999),
      );
      canvas.drawRRect(
          pillRect, Paint()..color = isDark ? const Color(0xFF0A0B0D) : const Color(0xFF1F2430));
      tp.paint(canvas, Offset(plotW + 10, y - tp.height / 2));
    }

    // ===== 成交量副图 =====
    if (hasVolume && subPane > 0) {
      final top = size.height - timeAxis - subPane;
      // pane 分隔线
      canvas.drawLine(Offset(0, top), Offset(size.width, top), gridPaint);
      final maxVol = rawPoints.fold<double>(
          0, (m, p) => p.volume > m ? p.volume : m);
      if (maxVol > 0) {
        final barW = math.max(1.0, plotW / math.max(1, rawPoints.length) * 0.5);
        for (var i = 0; i < rawPoints.length; i++) {
          final p = rawPoints[i];
          if (p.volume <= 0) continue;
          final prev = i > 0 ? rawPoints[i - 1].value : (p.previousClose ?? p.value);
          final up = p.value >= prev;
          final h = p.volume / maxVol * (subPane - 6);
          final x = xAt(i);
          canvas.drawRect(
            Rect.fromLTWH(x - barW / 2, top + subPane - h, barW, h),
            Paint()
              ..color = up
                  ? const Color(0xFFF5465C).withValues(alpha: 0.85)
                  : const Color(0xFF20B083).withValues(alpha: 0.85),
          );
        }
      }
    }

    // ===== 触摸十字线 + 呼吸点 =====
    if (hoverIndex >= 0 && hoverIndex < rawPoints.length) {
      final p = rawPoints[hoverIndex];
      final x = xAt(hoverIndex), y = yAt(p.value);
      final dashPaint = Paint()
        ..color = isDark ? const Color(0xFF8A93A6) : const Color(0xFF8A93A6)
        ..strokeWidth = 1;
      for (var yy = 0.0; yy < mainH; yy += 6) {
        canvas.drawLine(Offset(x, yy), Offset(x, math.min(yy + 3, mainH)), dashPaint);
      }
      // 呼吸光点（静态环近似）
      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = const Color(0x5920B083));
      canvas.drawCircle(
          Offset(x, y), 2.5, Paint()..color = const Color(0xFF20B083));
    }
  }

  String _hhmm(int unixSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  TextPainter _layoutText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _drawText(Canvas canvas, String text, Offset at, TextStyle style) {
    _layoutText(text, style).paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.rawPoints != rawPoints ||
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.isDark != isDark;
}
