import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

// TODO: 以下端点暂未收录进 ApiEndpoints，对齐 uni-app api/api.js 后建议迁入
// （getAssetTrades: GET /asset/api/Asset/{assetId}/trades）
class _TradingRecordEndpoints {
  static const assetTrades = ApiEndpoints.assetTrades; // GET /{assetId}/trades
}

/// 一条交易记录（对齐 trading-record.vue normalizeRecord 的输出）
class _TradeRow {
  final String id;
  final String typeText;
  final String tone; // rise / fall / neutral / edit
  final String typeKey; // all / buy / sell / fixed / redeem
  final String displayName;
  final String dateText;
  final int sortTime;
  final String amountText;
  final String effectiveText;

  const _TradeRow({
    required this.id,
    required this.typeText,
    required this.tone,
    required this.typeKey,
    required this.displayName,
    required this.dateText,
    required this.sortTime,
    required this.amountText,
    required this.effectiveText,
  });
}

/// 基金交易记录页 — uni-app 对应: pages/index/fund/trading-record.vue
/// 入口 query 参数: shortName / symbolId / symbolCode(code) / assetId / bookId / fromAllBooks。
///
/// 说明：源码用 chinese-days 判断基金交易日，这里内置 2024–2026 法定节假日表
/// 对齐（与 lib/pages/user/widgets/curve_holidays.dart 同一份数据；周末一律非交易日，
/// 调休工作日为周末时不影响结果，与源码 isFundTradingDay 行为一致）。
class FundTradingRecordPage extends StatefulWidget {
  final String shortName;
  final String symbolId;
  final String symbolCode;
  final String assetId;
  final int? bookId;
  final bool fromAllBooks;

  const FundTradingRecordPage({
    super.key,
    this.shortName = '',
    this.symbolId = '',
    this.symbolCode = '',
    this.assetId = '',
    this.bookId,
    this.fromAllBooks = false,
  });

  @override
  State<FundTradingRecordPage> createState() => _FundTradingRecordPageState();
}

class _FundTradingRecordPageState extends State<FundTradingRecordPage> {
  final ApiClient _api = ApiClient();
  final ScrollController _scrollCtl = ScrollController();

  static const _pageSize = 20;
  static const _tradeTypeTabs = [
    (label: '全部', value: 'all'),
    (label: '买入', value: 'buy'),
    (label: '卖出', value: 'sell'),
    (label: '定投', value: 'fixed'),
    (label: '赎回', value: 'redeem'),
  ];
  static const _tradeTypeMap = {
    1: (label: '买入', tone: 'rise', tab: 'buy'),
    2: (label: '卖出', tone: 'fall', tab: 'sell'),
    3: (label: '定投', tone: 'rise', tab: 'fixed'),
    4: (label: '赎回', tone: 'fall', tab: 'redeem'),
  };
  static const _hiddenTradeTypes = {5, 6};
  static const _hiddenTradeLabels = {'修正'};

  bool _loading = false;
  bool _loadingMore = false;
  int _visibleCount = _pageSize;
  String _activeTradeType = 'all';
  List<_TradeRow> _tradeRows = [];
  late bool _fromAllBooks;

  // ===== 生命周期 =====

  @override
  void initState() {
    super.initState();
    // 源码 onLoad: 判断是否「全部账本」视图
    final targetAssetId = int.tryParse(widget.assetId);
    final targetBookId = widget.bookId;
    final hasRealTarget = targetAssetId != null &&
        targetAssetId != -1 &&
        targetBookId != null &&
        targetBookId != -1;
    _fromAllBooks = !hasRealTarget &&
        (widget.fromAllBooks || targetBookId == -1 || targetAssetId == -1);
    _scrollCtl.addListener(_onScroll);
    _loadTrades();
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtl.hasClients) return;
    if (_scrollCtl.position.pixels >= _scrollCtl.position.maxScrollExtent - 50) {
      _loadMore();
    }
  }

  // ===== 工具函数（源码 pickFirstText / toFiniteNumber / normalizeNumber） =====

  String _pickFirstText(List<dynamic> values) {
    for (final v in values) {
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  double? _toFiniteNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // ===== 金额 / 日期格式化 =====

  /// 源码 formatTradeMoney: 卖出(type=2)取负，其余带符号，两位小数
  String _formatTradeMoney(dynamic value, dynamic typeValue) {
    final number = _toFiniteNumber(value);
    if (number == null) return '--';
    final typeNum = _toFiniteNumber(typeValue);
    if (typeNum == 2) return '-${number.abs().toStringAsFixed(2)}';
    return '${number >= 0 ? '+' : ''}${number.toStringAsFixed(2)}';
  }

  /// 源码 formatDate: 取前 10 位
  String _formatDate(dynamic value) {
    if (value == null) return '--';
    final s = value.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String _formatDateValue(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

  /// 源码 parseTradeDate: 优先 yyyy-MM-dd / yyyy/M/d，其次 Date 解析
  DateTime? _parseTradeDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m != null) {
      return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    }
    return DateTime.tryParse(s);
  }

  // ===== 基金交易日（源码 isFundTradingDay / addFundTradingDays，对齐 chinese-days） =====

  /// 2024–2026 落在工作日的法定节假日（与 curve_holidays.dart 数据一致）
  static const _kHolidayDates = <String>{
    // 2024
    '2024-01-01',
    '2024-02-12', '2024-02-13', '2024-02-14', '2024-02-15', '2024-02-16',
    '2024-04-04', '2024-04-05',
    '2024-05-01', '2024-05-02', '2024-05-03',
    '2024-06-10',
    '2024-09-17',
    '2024-10-01', '2024-10-02', '2024-10-03', '2024-10-04',
    // 2025
    '2025-01-01',
    '2025-01-28', '2025-01-29', '2025-01-30', '2025-01-31',
    '2025-02-03', '2025-02-04',
    '2025-04-04',
    '2025-05-01', '2025-05-02', '2025-05-05',
    '2025-06-02',
    '2025-10-01', '2025-10-02', '2025-10-03',
    '2025-10-06', '2025-10-07', '2025-10-08',
    // 2026
    '2026-01-01', '2026-01-02',
    '2026-02-16', '2026-02-17', '2026-02-18', '2026-02-19', '2026-02-20',
    '2026-02-23',
    '2026-04-06',
    '2026-05-01', '2026-05-04', '2026-05-05',
    '2026-06-19',
    '2026-09-25',
    '2026-10-01', '2026-10-02', '2026-10-05', '2026-10-06', '2026-10-07',
  };

  bool _isFundTradingDay(DateTime date) {
    // 源码: 周末(含调休上班周末)一律非交易日
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) return false;
    return !_kHolidayDates.contains(_formatDateValue(date));
  }

  /// 源码 addFundTradingDays: 从成交日起累加 N 个交易日，最多找 60 天
  String _addFundTradingDays(dynamic value, int days) {
    final date = _parseTradeDate(value);
    if (date == null) return '';
    var added = 0;
    var cursor = date;
    for (var i = 0; i < 60 && added < days; i++) {
      cursor = cursor.add(const Duration(days: 1));
      if (_isFundTradingDay(cursor)) added++;
    }
    return added == days ? _formatDateValue(cursor) : '';
  }

  /// 源码 getTradeTimePeriod: 15:00前 / 15:00后
  String _getTradeTimePeriod(dynamic value) {
    if (value == null) return '';
    final m = RegExp(r'T?(\d{1,2}):(\d{2})').firstMatch(value.toString());
    if (m == null) return '';
    final minutes = int.parse(m[1]!) * 60 + int.parse(m[2]!);
    return minutes < 15 * 60 ? '15:00前' : '15:00后';
  }

  /// 源码 getTradeEffectiveText: 15点前 +1 交易日，15点后 +2 交易日
  String _getTradeEffectiveText(dynamic value) {
    if (value == null) return '';
    final m = RegExp(r'T?(\d{1,2}):(\d{2})').firstMatch(value.toString());
    if (m == null) return '';
    final minutes = int.parse(m[1]!) * 60 + int.parse(m[2]!);
    final effectiveDate = _addFundTradingDays(value, minutes < 15 * 60 ? 1 : 2);
    return effectiveDate.isNotEmpty ? '收益生效时间 $effectiveDate' : '';
  }

  String _formatTradeDateTime(dynamic value) {
    final dateText = _formatDate(value);
    final periodText = _getTradeTimePeriod(value);
    return periodText.isNotEmpty ? '$dateText $periodText' : dateText;
  }

  // ===== 数据归一化（源码 unwrapAssetList / normalizeTradeList / normalizeRecord） =====

  List<dynamic> _unwrapAssetList(Response res) {
    final data = _unwrap(res);
    if (data is Map && data['list'] is List) return data['list'] as List;
    if (data is List) return data;
    final body = res.data;
    if (body is Map && body['list'] is List) return body['list'] as List;
    return const [];
  }

  List<dynamic> _normalizeTradeList(Response res) {
    final data = _unwrap(res);
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['items', 'records', 'list', 'rows']) {
        if (data[key] is List) return data[key] as List;
      }
      final inner = data['data'];
      if (inner is Map) {
        for (final key in ['items', 'records', 'list']) {
          if (inner[key] is List) return inner[key] as List;
        }
      }
    }
    return const [];
  }

  String _formatFundDisplayName(Map<String, dynamic> item) {
    final symbolInfo = item['symbolInfo'] is Map
        ? (item['symbolInfo'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final name = _pickFirstText([
      item['shortName'],
      item['symbolName'],
      item['fundName'],
      item['name'],
      symbolInfo['shortName'],
      item['assetName'],
      widget.shortName,
    ]);
    final code = _pickFirstText([
      item['symbolCode'],
      item['code'],
      item['displayCode'],
      item['fundCode'],
      item['symbol'],
      item['uniqueSymbol'],
      symbolInfo['code'],
      widget.symbolCode.isNotEmpty ? widget.symbolCode : widget.symbolId,
    ]);
    if (name.isNotEmpty && code.isNotEmpty) return '$name $code';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return '--';
  }

  _TradeRow _normalizeRecord(Map<String, dynamic> item, int index) {
    final typeValue = _toFiniteNumber(
            item['transactionType'] ?? item['tradeType'] ?? item['type'])
        ?.toInt();
    final typeInfo = _tradeTypeMap[typeValue] ??
        (
          label: (item['transactionTypeName'] ?? item['tradeTypeName'] ?? '交易').toString(),
          tone: 'neutral',
          tab: 'all',
        );
    final amount = item['totalAmount'] ?? item['amount'] ?? item['tradeAmount'];
    final transactionTime = item['transactionTime'] ?? item['tradeTime'] ?? item['date'];
    final sortTime = _parseTradeDate(transactionTime)?.millisecondsSinceEpoch ?? 0;
    final fallbackId =
        '${item['assetId'] ?? item['symbolId'] ?? 'trade'}-${transactionTime ?? index}';
    return _TradeRow(
      id: (item['id'] ?? item['recordId'] ?? item['tradeId'] ?? fallbackId).toString(),
      typeText: (item['transactionTypeName'] ?? item['tradeTypeName'] ?? typeInfo.label)
          .toString(),
      tone: typeInfo.tone,
      typeKey: typeInfo.tab,
      displayName: _formatFundDisplayName(item),
      dateText: _formatTradeDateTime(transactionTime),
      sortTime: sortTime,
      amountText: '${_formatTradeMoney(amount, typeValue)}元',
      effectiveText: _getTradeEffectiveText(transactionTime),
    );
  }

  /// 源码 isVisibleTradeRecord: 隐藏 type 5/6 与「修正」
  bool _isVisibleTradeRecord(Map<String, dynamic> item) {
    final typeValue =
        _toFiniteNumber(item['transactionType'] ?? item['tradeType'] ?? item['type'])?.toInt();
    final typeLabel = (item['transactionTypeName'] ??
            item['tradeTypeName'] ??
            _tradeTypeMap[typeValue]?.label ??
            '')
        .toString();
    return !_hiddenTradeTypes.contains(typeValue) && !_hiddenTradeLabels.contains(typeLabel);
  }

  // ===== 数据加载（源码 getRealAssetRows / loadTradesByAsset / loadTrades） =====

  List<Map<String, dynamic>> _getRealAssetRows(List<dynamic> list) {
    final targetSymbolId = _toFiniteNumber(widget.symbolId);
    final targetBookId =
        widget.bookId == null ? null : _toFiniteNumber(widget.bookId);
    final bookMap = <int, Map<String, dynamic>>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final currentBookId = _toFiniteNumber(item['bookId'])?.toInt();
      final currentAssetId = _toFiniteNumber(item['assetId'])?.toInt();
      final currentSymbolId = _toFiniteNumber(item['symbolId'])?.toInt();
      if (currentBookId == null || currentBookId == -1) continue;
      if (currentAssetId == null || currentAssetId == -1) continue;
      if (targetSymbolId != null &&
          currentSymbolId != null &&
          currentSymbolId != targetSymbolId) {
        continue;
      }
      if (!_fromAllBooks && targetBookId != null && currentBookId != targetBookId) {
        continue;
      }
      bookMap.putIfAbsent(currentBookId, () => item);
    }
    return bookMap.values.toList();
  }

  Future<List<dynamic>> _loadTradesByAsset(dynamic targetAssetId) async {
    if (targetAssetId == null || '$targetAssetId'.isEmpty) return const [];
    final res = await _api.get('${_TradingRecordEndpoints.assetTrades}/$targetAssetId/trades');
    return _normalizeTradeList(res);
  }

  Future<void> _loadTrades() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    try {
      var rows = <dynamic>[];
      if (widget.assetId.isNotEmpty && !_fromAllBooks) {
        rows = await _loadTradesByAsset(widget.assetId);
      } else if (widget.symbolId.isNotEmpty) {
        final assetRes = await _api.get('${ApiEndpoints.assetBySymbol}/${widget.symbolId}');
        final assetRows = _getRealAssetRows(_unwrapAssetList(assetRes));
        if (assetRows.isNotEmpty) {
          final result = await Future.wait(
              assetRows.map((item) => _loadTradesByAsset(item['assetId'])));
          rows = result.expand((e) => e).toList();
        } else if (widget.assetId.isNotEmpty) {
          rows = await _loadTradesByAsset(widget.assetId);
        }
      } else if (widget.assetId.isNotEmpty) {
        rows = await _loadTradesByAsset(widget.assetId);
      }
      final normalized = rows
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .where(_isVisibleTradeRecord)
          .toList();
      final records = <_TradeRow>[
        for (var i = 0; i < normalized.length; i++) _normalizeRecord(normalized[i], i),
      ]..sort((a, b) => b.sortTime.compareTo(a.sortTime));
      if (mounted) {
        setState(() {
          _tradeRows = records;
          _visibleCount = _pageSize;
        });
      }
    } catch (_) {
      // 源码: console.error('获取交易记录失败') + toast
      _toast('获取交易记录失败');
      if (mounted) setState(() => _tradeRows = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_TradeRow> get _filteredRows {
    if (_activeTradeType == 'all') return _tradeRows;
    return _tradeRows.where((item) => item.typeKey == _activeTradeType).toList();
  }

  List<_TradeRow> get _displayRecords =>
      _filteredRows.take(_visibleCount).toList();

  bool get _hasMore => _filteredRows.length > _visibleCount;

  void _loadMore() {
    if (!_hasMore || _loading || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _visibleCount =
          (_visibleCount + _pageSize).clamp(0, _filteredRows.length);
      _loadingMore = false;
    });
  }

  void _handleTradeTypeChange(String value) {
    if (_activeTradeType == value) return;
    setState(() {
      _activeTradeType = value;
      _visibleCount = _pageSize;
    });
  }

  // ============================================================
  // UI
  // ============================================================

  Color _toneColor(String tone) {
    switch (tone) {
      case 'rise':
        return AppColors.upColor; // #E05665
      case 'fall':
        return AppColors.positionDownColor; // #00B26A
      case 'edit':
        return const Color(0xFF4F83E8);
      default:
        return const Color(0xFF8F949D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5),
      appBar: CustomNavBar(
        title: '交易记录',
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF5F5F5),
      ),
      body: Column(
        children: [
          _buildTypeTabs(isDark),
          Expanded(child: _buildRecordList(isDark)),
        ],
      ),
    );
  }

  /// 交易类型筛选 tabs（type-tabs）
  Widget _buildTypeTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9), // 18rpx 12rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC),
              width: 0.5),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tradeTypeTabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 5), // 10rpx
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleTradeTypeChange(_tradeTypeTabs[i].value),
                child: Container(
                  height: 26, // 52rpx
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _activeTradeType == _tradeTypeTabs[i].value
                        ? (isDark
                            ? const Color(0x29E05665) // rgba(224,86,101,0.16)
                            : const Color(0xFFFFECEF))
                        : (isDark
                            ? const Color(0xFF282828)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _tradeTypeTabs[i].label,
                    style: AppTextStyles.cn(
                      12, // 24rpx
                      color: _activeTradeType == _tradeTypeTabs[i].value
                          ? AppColors.upColor
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF8D8B87)),
                      weight: _activeTradeType == _tradeTypeTabs[i].value
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 记录列表（record-scroll / record-list）
  Widget _buildRecordList(bool isDark) {
    final records = _displayRecords;
    if (_loading && records.isEmpty) {
      return _buildStateText(isDark, '加载中...');
    }
    if (records.isEmpty) {
      return _buildStateText(isDark, '暂无交易记录');
    }
    return ListView.builder(
      controller: _scrollCtl,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 20), // 18rpx 24rpx 40rpx
      itemCount: records.length + 1,
      itemBuilder: (context, index) {
        if (index == records.length) return _buildLoadMore(isDark);
        return _buildRecordItem(records[index], isDark);
      },
    );
  }

  Widget _buildStateText(bool isDark, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28), // 56rpx 24rpx
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTextStyles.cn(12,
            color: isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87)),
      ),
    );
  }

  Widget _buildLoadMore(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // 22rpx 24rpx
      alignment: Alignment.center,
      child: Text(
        _hasMore ? (_loadingMore ? '加载中...' : '上拉加载更多') : '没有更多了',
        style: AppTextStyles.cn(12,
            color: isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87)),
      ),
    );
  }

  /// 单条交易记录（record-item）
  Widget _buildRecordItem(_TradeRow item, bool isDark) {
    final toneColor = _toneColor(item.tone);
    final mutedColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // 16rpx
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20), // 40rpx 24rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A452008), // rgba(69,32,8,0.04)
                  blurRadius: 9, // 18rpx
                  offset: Offset(0, 4), // 8rpx
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧: 类型 + 名称/日期
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1), // 2rpx
                  child: Text(
                    item.typeText,
                    style: AppTextStyles.cn(14,
                        color: toneColor, weight: FontWeight.w700, height: 18 / 14),
                  ),
                ),
                const SizedBox(width: 7), // 14rpx
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 18, // 36rpx
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cn(
                              14,
                              color: isDark
                                  ? AppColors.darkText
                                  : const Color(0xFF23283C),
                              height: 18 / 14,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5), // 10rpx
                        child: Text(
                          item.dateText,
                          style: AppTextStyles.cn(11, color: mutedColor, height: 14 / 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右侧: 金额 + 收益生效时间
          const SizedBox(width: 10), // 20rpx
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.amountText,
                style: AppTextStyles.num(15, color: toneColor, height: 17 / 15),
              ),
              if (item.effectiveText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5), // 10rpx
                  child: Text(
                    item.effectiveText,
                    maxLines: 1,
                    style: AppTextStyles.cn(11, color: mutedColor, height: 1.3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
