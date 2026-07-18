import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import 'widgets/trading_record_trade_days.dart';
import 'widgets/trading_record_widgets.dart';

/// 交易记录页 — 1:1 复刻 uni-app pages/positionv1/trading-record.vue
/// 类型 Tab 筛选 + z-paging 分页（下拉刷新/上拉加载）+ 搜索选基金过滤
/// query: bookId (可选, 指定账本), fundCode/fundName (可选, 预选基金过滤)
///
/// 平台差异说明：
/// - umeng 埋点 (trackUmengEvent) 不实现（平台专有能力）。
/// - 搜索页从 SharedPreferences 接力改为 await context.push 接收 pop 结果
///   （对齐 position_search_page.dart 既有约定）。
/// - 基金交易日判断内嵌 chinese-days 2004-2026 法定节假日数据
///   （见 widgets/trading_record_trade_days.dart，逻辑与源码一致：
///   周末非交易日，调休工作日因属周末同样被排除）。
class TradingRecordPage extends StatefulWidget {
  final int? bookId;
  final String fundCode;
  final String fundName;
  const TradingRecordPage({super.key, this.bookId, this.fundCode = '', this.fundName = ''});

  @override
  State<TradingRecordPage> createState() => _TradingRecordPageState();
}

/// uni-app api.js queryAssetTrades → POST /asset/api/Asset/trades/query
const _endpointQueryAssetTrades = ApiEndpoints.assetTradesQuery;

/// 列表行视图模型 (uni-app normalizeRecord 的产物)
class TradingRecordView {
  final String id;
  final String typeText;
  final TradingRecordTone tone;
  final String displayName;
  final String dateText;
  final String amountText;
  final String effectiveText;

  const TradingRecordView({
    required this.id,
    required this.typeText,
    required this.tone,
    required this.displayName,
    required this.dateText,
    required this.amountText,
    required this.effectiveText,
  });
}

/// uni-app tradeTypeMap: value → (label, tone)
const _tradeTypeMap = {
  1: (label: '买入', tone: TradingRecordTone.rise),
  2: (label: '卖出', tone: TradingRecordTone.fall),
  3: (label: '分红', tone: TradingRecordTone.rise),
  4: (label: '转换', tone: TradingRecordTone.neutral),
  5: (label: '定投', tone: TradingRecordTone.rise),
  6: (label: '修正', tone: TradingRecordTone.neutral),
  7: (label: '其他', tone: TradingRecordTone.neutral),
};

/// uni-app hiddenTradeTypes / hiddenTradeLabels (列表中隐藏的类型)
const _hiddenTradeTypes = {3, 6, 7};
const _hiddenTradeLabels = {'分红', '修正', '其他'};

class _TradingRecordPageState extends State<TradingRecordPage> {
  static const _pageSize = 20;
  final ApiClient _api = ApiClient();
  final ScrollController _scrollController = ScrollController();

  int _activeTradeType = 0;
  late String _fundCode = widget.fundCode;
  late String _fundName = widget.fundName;

  final List<TradingRecordView> _records = [];
  int _pageNo = 1;
  bool _noMore = false;
  bool _loading = false;
  bool _loadError = false;
  bool _firstLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _query(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  // ===== 解析工具 (1:1 uni-app) =====

  /// JS `a || b` 语义 (空串/0 视为空)
  String? _jsOr(dynamic value) {
    if (value == null) return null;
    if (value is num) return value == 0 ? null : value.toString();
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  /// uni-app pickFirstText: 第一个 trim 后非空的值
  String _pickFirstText(List<dynamic> values) {
    for (final v in values) {
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  int? _typeValueOf(Map item) {
    final raw = item['transactionType'] ?? item['tradeType'] ?? item['type'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  /// uni-app isVisibleTradeRecord: 隐藏 分红/修正/其他
  bool _isVisibleTradeRecord(Map item) {
    final typeValue = _typeValueOf(item);
    final typeLabel = _jsOr(item['transactionTypeName']) ??
        _jsOr(item['tradeTypeName']) ??
        (typeValue != null ? _tradeTypeMap[typeValue]?.label : null) ??
        '';
    return !_hiddenTradeTypes.contains(typeValue) && !_hiddenTradeLabels.contains(typeLabel);
  }

  /// uni-app getFundDisplayInfo
  ({String name, String code}) _fundDisplayInfo(Map item) {
    final symbolInfo = item['symbolInfo'];
    final symbolMap = symbolInfo is Map ? symbolInfo : const {};
    final name = _pickFirstText([
      item['shortName'],
      item['symbolName'],
      item['fundName'],
      item['name'],
      symbolMap['shortName'],
      item['assetName'],
    ]);
    final code = _pickFirstText([
      item['symbolCode'],
      item['code'],
      item['displayCode'],
      item['fundCode'],
      item['symbol'],
      item['uniqueSymbol'],
      symbolMap['code'],
    ]);
    return (name: name.isNotEmpty ? name : (code.isNotEmpty ? code : '--'), code: code);
  }

  /// uni-app formatDate: 取时间串前 10 位
  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '--';
    return value.length > 10 ? value.substring(0, 10) : value;
  }

  /// uni-app formatTradeDateTime: 日期 + 15:00前/后
  String _formatTradeDateTime(String? value) {
    final dateText = _formatDate(value);
    final period = TradingRecordTradeDays.tradeTimePeriod(value);
    return period.isNotEmpty ? '$dateText $period' : dateText;
  }

  /// uni-app formatRecordSubText: code - 时间
  String _formatRecordSubText(String code, String? transactionTime) {
    final timeText = _formatTradeDateTime(transactionTime);
    if (code.isNotEmpty && timeText.isNotEmpty) return '$code - $timeText';
    if (code.isNotEmpty) return code;
    return timeText.isNotEmpty ? timeText : '--';
  }

  /// uni-app formatTradeMoney
  String _formatTradeMoney(dynamic value, int? typeValue) {
    double? number;
    if (value is num) {
      number = value.toDouble();
    } else if (value != null) {
      number = double.tryParse(value.toString());
    }
    if (number == null) return '--';
    if (typeValue == 2) return '-${number.abs().toStringAsFixed(2)}';
    return '${number >= 0 ? '+' : ''}${number.toStringAsFixed(2)}';
  }

  /// uni-app normalizeRecord
  TradingRecordView _normalizeRecord(Map item, int index) {
    final typeValue = _typeValueOf(item);
    final typeInfo = typeValue != null ? _tradeTypeMap[typeValue] : null;
    final fallbackLabel = _jsOr(item['transactionTypeName']) ?? _jsOr(item['tradeTypeName']) ?? '交易';
    final label = typeInfo?.label ?? fallbackLabel;
    final tone = typeInfo?.tone ?? TradingRecordTone.neutral;
    final amount = item['totalAmount'] ?? item['amount'] ?? item['tradeAmount'];
    final transactionTime = _jsOr(item['transactionTime']) ?? _jsOr(item['tradeTime']) ?? _jsOr(item['date']);
    final fundInfo = _fundDisplayInfo(item);
    final isCorrection = typeValue == 6 || label == '修正';

    final rawId = _jsOr(item['id']) ?? _jsOr(item['recordId']) ?? _jsOr(item['tradeId']);
    final id = rawId ??
        '${_jsOr(item['assetId']) ?? _jsOr(item['symbolId']) ?? 'trade'}-${transactionTime ?? index}';

    return TradingRecordView(
      id: id,
      typeText: _jsOr(item['transactionTypeName']) ?? _jsOr(item['tradeTypeName']) ?? label,
      tone: tone,
      displayName: fundInfo.name,
      dateText: _formatRecordSubText(fundInfo.code, transactionTime),
      amountText: '${_formatTradeMoney(amount, typeValue)}元',
      effectiveText: isCorrection ? '' : TradingRecordTradeDays.tradeEffectiveText(transactionTime),
    );
  }

  /// uni-app unwrapTradeRows
  List _unwrapTradeRows(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final k in const ['items', 'records', 'list', 'rows']) {
        if (body[k] is List) return body[k] as List;
      }
      final inner = body['data'];
      if (inner is Map) {
        for (final k in const ['items', 'records', 'list']) {
          if (inner[k] is List) return inner[k] as List;
        }
      }
    }
    return const [];
  }

  /// uni-app unwrapTotal
  double? _unwrapTotal(dynamic body) {
    if (body is! Map) return null;
    final pageData = body['data'] is Map ? body['data'] as Map : body;
    for (final k in const ['total', 'totalCount', 'count']) {
      final v = pageData[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // ===== 查询 (uni-app buildRequest / handlePagingQuery) =====

  Map<String, dynamic> _buildRequest(int pageNo, int pageSize) {
    final body = <String, dynamic>{'pageIndex': pageNo, 'pageSize': pageSize};
    final bookId = widget.bookId;
    if (bookId != null) body['bookId'] = bookId;
    if (_activeTradeType != 0) body['transactionType'] = _activeTradeType;
    if (_fundCode.isNotEmpty) body['fundCode'] = _fundCode;
    return body;
  }

  Future<void> _query(int pageNo) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await _api.post(_endpointQueryAssetTrades, data: _buildRequest(pageNo, _pageSize));
      final rows = _unwrapTradeRows(res.data);
      final nextRecords = <TradingRecordView>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row is! Map || !_isVisibleTradeRecord(row)) continue;
        nextRecords.add(_normalizeRecord(row, i));
      }
      final total = _unwrapTotal(res.data);
      final noMore = total != null ? pageNo * _pageSize >= total : rows.length < _pageSize;
      if (!mounted) return;
      setState(() {
        if (pageNo == 1) _records.clear();
        _records.addAll(nextRecords);
        _pageNo = pageNo;
        _noMore = noMore;
        _loadError = false;
        _firstLoaded = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('获取交易记录失败');
      setState(() {
        _loadError = true;
        _firstLoaded = true;
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) _loadMore();
  }

  /// z-paging 上拉加载更多
  void _loadMore() {
    if (_loading || _noMore || _loadError || _records.isEmpty || !_firstLoaded) return;
    _query(_pageNo + 1);
  }

  /// uni-app handleTradeTypeChange: 切 Tab 后重新加载
  void _handleTradeTypeChange(int value) {
    if (_activeTradeType == value) return;
    setState(() => _activeTradeType = value);
    _query(1);
  }

  // ===== 搜索选基金 (uni-app goSearch / applySelectedFund) =====

  Future<void> _goSearch() async {
    final query = ['from=trading-record'];
    final bookId = widget.bookId;
    if (bookId != null) query.add('bookId=$bookId');
    // position_search_page.dart: from='trading-record' 时 pop {source, fundCode, fundName, bookId?}
    final result = await context.push('/position-search?${query.join('&')}');
    if (!mounted || result is! Map) return;
    if (result['source'] != 'trading-record') return;
    _applySelectedFund(result);
  }

  void _applySelectedFund(Map payload) {
    final nextFundCode = payload['fundCode']?.toString() ?? '';
    final nextFundName = payload['fundName']?.toString() ?? '';
    if (_fundCode == nextFundCode && _fundName == nextFundName) return;
    setState(() {
      _fundCode = nextFundCode;
      _fundName = nextFundName;
    });
    _query(1);
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(children: [
        CustomNavBar(
          title: '交易记录',
          backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
          titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
          rightWidget: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goSearch,
            child: SizedBox(
              width: 32, // 64rpx
              height: 32,
              child: Center(
                child: Icon(
                  AppIcons.search,
                  size: 22, // uni-icons search size=22
                  color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
        TradingRecordTypeTabs(
          activeValue: _activeTradeType,
          isDark: isDark,
          onChanged: _handleTradeTypeChange,
        ),
        Expanded(child: _buildBody(isDark)),
      ]),
    );
  }

  Widget _buildBody(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);
    // 首次加载中
    if (!_firstLoaded && _loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    // 空列表: 加载失败 → 重试; 否则 → 暂无交易记录
    if (_records.isEmpty) {
      return ZPagingRefresh(
        onRefresh: () => _query(1),
        isDark: isDark,
        titleColor: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _loadError ? () => _query(1) : null,
              child: Center(
                child: Text(
                  _loadError ? '加载失败，点击重试' : '暂无交易记录', // empty-view-text
                  style: AppTextStyles.cn(13, color: mutedColor),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ZPagingRefresh(
      onRefresh: () => _query(1),
      isDark: isDark,
      controller: _scrollController,
      titleColor: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 20), // 18rpx 24rpx 40rpx
          sliver: SliverList.builder(
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final item = _records[index];
              return TradingRecordItem(
                key: ValueKey(item.id),
                typeText: item.typeText,
                tone: item.tone,
                displayName: item.displayName,
                dateText: item.dateText,
                amountText: item.amountText,
                effectiveText: item.effectiveText,
                isDark: isDark,
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: _buildFooter(isDark)),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    final TradingRecordFooterState state;
    if (_loadError) {
      state = TradingRecordFooterState.error;
    } else if (_noMore) {
      state = TradingRecordFooterState.noMore;
    } else if (_loading) {
      state = TradingRecordFooterState.loading;
    } else {
      state = TradingRecordFooterState.idle;
    }
    return TradingRecordFooter(
      state: state,
      isDark: isDark,
      onRetry: () => _query(_pageNo),
    );
  }
}
