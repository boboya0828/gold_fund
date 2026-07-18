import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/gjs_book_confirm_dialog.dart';
import 'widgets/running_tab_wheel_picker.dart';

// TODO: 以下端点暂未收录进 ApiEndpoints，对齐 uni-app api/api.js 后建议迁入
// （getSymbolInfo: GET /asset/api/Symbol/{symbolId}）
class _GjsBookEndpoints {
  static const assetSymbolInfo = ApiEndpoints.assetSymbolInfo; // GET /{symbolId} — getSymbolInfo
}

/// 日期选项 { label: '06月01日(周一)' / '今日', value: '2024-06-01' }
class _DateOption {
  final String label;
  final String value;
  const _DateOption(this.label, this.value);
}

/// 贵金属记账页（买入/卖出） — uni-app 对应: pages/index/fund/gjs-bookkeeping.vue
/// 入口 query 参数: activeTab(buy/sell) / uniqueSymbol / shortName / symbolId / assetId / bookId。
class GjsBookkeepingPage extends StatefulWidget {
  final String activeTab; // buy / sell
  final String uniqueSymbol;
  final String shortName;
  final int? symbolId;
  final String assetId;
  final int bookId;

  const GjsBookkeepingPage({
    super.key,
    this.activeTab = 'buy',
    this.uniqueSymbol = '',
    this.shortName = '',
    this.symbolId,
    this.assetId = '',
    this.bookId = 0,
  });

  @override
  State<GjsBookkeepingPage> createState() => _GjsBookkeepingPageState();
}

class _GjsBookkeepingPageState extends State<GjsBookkeepingPage> {
  final ApiClient _api = ApiClient();

  static const _tabList = [
    (label: '买入', value: 'buy'),
    (label: '卖出', value: 'sell'),
  ];
  static const _weekText = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  late String _activeTab = widget.activeTab == 'sell' ? 'sell' : 'buy';

  final _goldWeightCtl = TextEditingController();
  final _totalAmountCtl = TextEditingController();
  final _remarkCtl = TextEditingController();

  bool _noticeVisible = true;
  bool _submitting = false;

  late final String _uniqueSymbol = widget.uniqueSymbol;
  late final String _shortName = widget.shortName;
  late final int? _symbolId = widget.symbolId;
  late String _assetId = widget.assetId;
  late final int _bookId = widget.bookId;
  Map<String, dynamic> _symbolInfo = {};
  Map<String, dynamic> _positionInfo = {};

  late final List<_DateOption> _dateOptions = _createDateOptions();
  late int _selectedDateIndex = _dateOptions.length - 1;

  // ===== 生命周期 =====

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _goldWeightCtl.dispose();
    _totalAmountCtl.dispose();
    _remarkCtl.dispose();
    super.dispose();
  }

  /// 源码 onLoad: 记录搜索 + 并行加载标的信息/持仓
  Future<void> _init() async {
    if (_symbolId == null) return;
    unawaited(_recordSearchOperate());
    try {
      await Future.wait([_loadSymbolBaseInfo(), _loadPositionInfo()]);
    } catch (_) {
      // 源码: console.error('贵金属交易页初始化失败')
    }
  }

  Future<void> _recordSearchOperate() async {
    try {
      // 源码: assetRecordSearch(symbolId)
      await _api.post('${ApiEndpoints.assetSymbolSearchOperate}?symbolId=$_symbolId');
    } catch (_) {}
  }

  Future<void> _loadSymbolBaseInfo() async {
    if (_symbolId == null) return;
    final res = await _api.get('${_GjsBookEndpoints.assetSymbolInfo}/$_symbolId');
    final data = _unwrap(res);
    if (mounted) setState(() => _symbolInfo = data is Map ? data.cast<String, dynamic>() : {});
  }

  Future<void> _loadPositionInfo() async {
    if (_symbolId == null) return;
    final res = await _api.get('${ApiEndpoints.assetBySymbol}/$_symbolId');
    final data = _unwrap(res);
    final rawList = <Map<String, dynamic>>[];
    if (data is Map && data['list'] is List) {
      rawList.addAll((data['list'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()));
    }
    // 源码: 过滤 bookId=-1 的汇总行，再按 assetId → bookId → 第一条 匹配
    final list = rawList.where((e) => _toInt(e['bookId']) != -1).toList();
    Map<String, dynamic>? matched;
    final targetAssetId = num.tryParse(_assetId);
    if (targetAssetId != null) {
      for (final item in list) {
        final itemAssetId = item['assetId'];
        final itemAssetNum =
            itemAssetId is num ? itemAssetId : num.tryParse('${itemAssetId ?? ''}');
        if (itemAssetNum != null && itemAssetNum == targetAssetId) {
          matched = item;
          break;
        }
      }
    }
    matched ??= list.where((e) => _toInt(e['bookId']) == _bookId).firstOrNull;
    matched ??= list.isNotEmpty ? list[0] : (rawList.isNotEmpty ? rawList[0] : null);
    if (mounted) {
      setState(() {
        _positionInfo = matched ?? {};
        if (_assetId.isEmpty && _positionInfo['assetId'] != null) {
          _assetId = '${_positionInfo['assetId']}';
        }
      });
    }
  }

  dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return e.message ?? '提交失败';
    }
    return e.toString();
  }

  void _toast(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
    );
  }

  // ===== 日期选项（源码 createDateOptions / formatDateText） =====

  static int _jsDay(DateTime d) => d.weekday % 7; // JS getDay(): 0=周日

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String _formatDateValue(DateTime d) =>
      '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

  /// 源码 formatDateText: 今日 → '今日'，否则 'MM月DD日(周X)'
  static String _formatDateText(DateTime d) {
    final today = _formatDateValue(DateTime.now());
    final value = _formatDateValue(d);
    if (value == today) return '今日';
    return '${_pad2(d.month)}月${_pad2(d.day)}日(${_weekText[_jsDay(d)]})';
  }

  /// 近一个月到今天
  static List<_DateOption> _createDateOptions() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    var current = DateTime(end.year, end.month - 1, end.day);
    final result = <_DateOption>[];
    while (!current.isAfter(end)) {
      result.add(_DateOption(_formatDateText(current), _formatDateValue(current)));
      current = DateTime(current.year, current.month, current.day + 1);
    }
    return result;
  }

  // ===== 数字 / 格式化（源码 toNumber / formatDecimal 等） =====

  double _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _formatDecimal(dynamic value, [int digits = 2]) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '--';
    return n.toStringAsFixed(digits);
  }

  /// 源码 formatCompactDecimal: 4 位小数后去尾零
  String _formatCompactDecimal(dynamic value, [int digits = 4]) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '--';
    var fixed = n.toStringAsFixed(digits);
    if (fixed.contains('.')) {
      fixed = fixed.replaceAll(RegExp(r'0+$'), '');
      if (fixed.endsWith('.')) fixed = fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  String _formatSignedPercent(dynamic value, [int digits = 2]) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '--';
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(digits)}%';
  }

  /// 源码 formatDateOnly: 取 yyyy-MM-dd
  String _formatDateOnly(dynamic value) {
    if (value == null) return '--';
    final m = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(value.toString());
    return m != null ? m[0]! : '--';
  }

  // ===== 计算属性（对齐源码 computed） =====

  Map<String, dynamic> get _latestPriceInfo => _symbolInfo['latestPrice'] is Map
      ? (_symbolInfo['latestPrice'] as Map).cast<String, dynamic>()
      : {};

  double get _latestPriceValue {
    final candidates = [
      _latestPriceInfo['latestPrice'],
      _latestPriceInfo['close'],
      _latestPriceInfo['preClose'],
      _positionInfo['curUnitPrice'],
      _positionInfo['avgCostPrice'],
    ];
    for (final item in candidates) {
      final n = item is num ? item.toDouble() : double.tryParse('${item ?? ''}');
      if (n != null && n > 0) return n;
    }
    return 0;
  }

  double get _latestChangeRatio => _toNumber(_latestPriceInfo['changeRatio']);

  String get _assetName => _shortName.isNotEmpty
      ? _shortName
      : (_symbolInfo['shortName'] ?? _symbolInfo['name'] ?? '--').toString();

  String get _assetCode =>
      (_symbolInfo['code'] ?? (_uniqueSymbol.isNotEmpty ? _uniqueSymbol : '--')).toString();

  String get _latestPriceDateText => _formatDateOnly(_latestPriceInfo['latestTime']);

  String get _latestPriceText =>
      _latestPriceValue > 0 ? _formatDecimal(_latestPriceValue, 2) : '--';

  String get _latestChangeRatioText => _latestPriceInfo['changeRatio'] == null
      ? '--'
      : _formatSignedPercent(_latestChangeRatio, 2);

  double get _holdingQuantity =>
      _toNumber(_positionInfo['holdQuantity'] ?? _positionInfo['quantity']);

  String get _holdingQuantityText => _formatCompactDecimal(_holdingQuantity, 4);

  String get _weightPlaceholder =>
      _activeTab == 'sell' && _holdingQuantity > 0
          ? '最多可卖出$_holdingQuantityText克'
          : '请输入黄金重量';

  String get _selectedDateLabel =>
      _selectedDateIndex >= 0 && _selectedDateIndex < _dateOptions.length
          ? _dateOptions[_selectedDateIndex].label
          : '今日';

  String get _selectedDateValue =>
      _selectedDateIndex >= 0 && _selectedDateIndex < _dateOptions.length
          ? _dateOptions[_selectedDateIndex].value
          : _formatDateValue(DateTime.now());

  String get _averagePriceText {
    final weight = _toNumber(_goldWeightCtl.text);
    final amount = _toNumber(_totalAmountCtl.text);
    if (weight == 0 || amount == 0) return '--';
    return _formatDecimal(amount / weight, 2);
  }

  String get _trimmedRemark => _remarkCtl.text.trim();

  String get _confirmWeight => _goldWeightCtl.text.isEmpty ? '0' : _goldWeightCtl.text;

  String get _confirmAmount => _totalAmountCtl.text.isEmpty ? '0.00' : _totalAmountCtl.text;

  String get _currentAssetId => _assetId.isNotEmpty
      ? _assetId
      : '${_positionInfo['assetId'] ?? _positionInfo['id'] ?? ''}';

  // ===== 交互 =====

  void _onInputChanged() => setState(() {});

  /// 源码 openDatePopup/confirmDatePopup（滚轮选择日期）
  Future<void> _openDatePopup() async {
    final result = await RunningTabWheelPicker.show(
      context,
      title: '选择日期',
      confirmText: '确定',
      pickerHeight: 250,
      initialIndexes: [_selectedDateIndex],
      columnsBuilder: (_) => [
        [for (final o in _dateOptions) RunningTabPickerItem(o.label, o.value)],
      ],
    );
    if (result != null) setState(() => _selectedDateIndex = result[0]);
  }

  /// 源码 openConfirmPopup（含校验）
  Future<void> _openConfirmPopup() async {
    final weight = _toNumber(_goldWeightCtl.text);
    final amount = _toNumber(_totalAmountCtl.text);
    if (weight == 0) return _toast('请输入黄金重量');
    if (amount == 0) return _toast('请输入成交总价');
    if (_activeTab == 'sell') {
      if (_currentAssetId.isEmpty) return _toast('当前暂无可卖出的持仓');
      if (_holdingQuantity > 0 && weight > _holdingQuantity) {
        return _toast('卖出重量不能超过可卖数量');
      }
    }
    final confirmed = await GjsBookConfirmDialog.show(
      context,
      title: _activeTab == 'buy' ? '买入确认' : '卖出确认',
      rows: [
        GjsBookConfirmRow('标的名称：', _assetName, numeric: false),
        GjsBookConfirmRow('黄金重量：', '$_confirmWeight 克'),
        GjsBookConfirmRow('成交总价：', '$_confirmAmount 元'),
        GjsBookConfirmRow('交易日期：', _selectedDateLabel),
        if (_trimmedRemark.isNotEmpty)
          GjsBookConfirmRow('备注：', _trimmedRemark, numeric: false),
      ],
    );
    if (confirmed) _handleConfirmSubmit();
  }

  /// 源码 buildTradePayload
  Map<String, dynamic> _buildTradePayload() {
    final payload = <String, dynamic>{
      'quantity': double.parse(_toNumber(_goldWeightCtl.text).toStringAsFixed(4)),
      'totalAmount': double.parse(_toNumber(_totalAmountCtl.text).toStringAsFixed(2)),
      'serviceFee': 0,
      'transactionTime': '${_selectedDateValue}T00:00:00',
    };
    if (_trimmedRemark.isNotEmpty) payload['remark'] = _trimmedRemark;
    return payload;
  }

  /// 源码 handleConfirmSubmit: 提交买入/卖出
  Future<void> _handleConfirmSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final payload = _buildTradePayload();
      if (_activeTab == 'buy') {
        if (_symbolId == null) {
          _toast('当前标的信息不完整');
          return;
        }
        await _api.post(ApiEndpoints.assetBuy, data: {
          ...payload,
          'bookId': _bookId,
          'symbolId': _symbolId,
        });
      } else {
        final sellAssetId = int.tryParse(_currentAssetId) ?? 0;
        if (sellAssetId == 0) {
          _toast('当前暂无可卖出的持仓');
          return;
        }
        await _api.post(ApiEndpoints.assetSell, data: {
          ...payload,
          'assetId': sellAssetId,
        });
      }
      if (!mounted) return;
      _toast('${_activeTab == 'buy' ? '买入' : '卖出'}成功!');
      // 源码: 300ms 后返回上一页
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    } catch (e) {
      if (mounted) _toast(_errMsg(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: CustomNavBar(
        title: '贵金属记账',
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          if (_noticeVisible) _buildNotice(isDark),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAssetCard(isDark),
                  Container(
                    margin: const EdgeInsets.only(top: 30), // 60rpx
                    height: 15, // 30rpx
                    color: isDark ? AppColors.darkBg : const Color(0xFFF1F1F3),
                  ),
                ],
              ),
            ),
          ),
          _buildSubmitBar(isDark),
        ],
      ),
    );
  }

  /// 顶部 买入/卖出 tab（gjs-tabs）
  Widget _buildTabBar(bool isDark) {
    final accent = isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F);
    return Container(
      height: 44, // 88rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFE9), width: 1),
        ),
      ),
      child: Row(
        children: [
          for (final item in _tabList)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_activeTab != item.value) setState(() => _activeTab = item.value);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.cn(
                        16, // 32rpx
                        color: _activeTab == item.value
                            ? accent
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFFCFC9C1)),
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (_activeTab == item.value)
                      Positioned(
                        bottom: 10, // 20rpx
                        child: Container(
                          width: 30, // 60rpx
                          height: 2, // 4rpx
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 模拟交易提示条（up-notice-bar，可关闭）
  Widget _buildNotice(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF282828) : const Color(0xFFFDF5F2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('此处为模拟交易，非真实交易，仅作为记账使用',
                style: AppTextStyles.cn(12, color: const Color(0xFFE05665))),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _noticeVisible = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 14, color: Color(0xFFE05665)),
            ),
          ),
        ],
      ),
    );
  }

  /// 贵金属信息卡 + 表单（gjs-card）
  Widget _buildAssetCard(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0), // 28rpx 24rpx 0
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAssetHeader(isDark),
          _buildForm(isDark),
        ],
      ),
    );
  }

  /// 名称 + 贵金属标签 + 最新克价（gjs-asset）
  Widget _buildAssetHeader(bool isDark) {
    final metaColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFB4B4B4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4), // 8rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _assetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cn(
                    16, // 32rpx
                    color: isDark ? AppColors.darkText : const Color(0xFF333333),
                    weight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 6), // 12rpx
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5), // 5rpx 14rpx
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x29B67726) : const Color(0xFFFFF2E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '贵金属',
                  style: AppTextStyles.cn(11, color: const Color(0xFFB67726), height: 1),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6), // 12rpx
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_assetCode, style: AppTextStyles.num(12, color: metaColor, height: 1.3)),
                Container(
                  width: 3, // 6rpx
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 5), // 10rpx
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8D1CA),
                    shape: BoxShape.circle,
                  ),
                ),
                Text('最新克价（', style: AppTextStyles.cn(12, color: metaColor, height: 1.3)),
                Text(_latestPriceDateText,
                    style: AppTextStyles.num(12, color: metaColor, height: 1.3)),
                Text('）', style: AppTextStyles.cn(12, color: metaColor, height: 1.3)),
                const SizedBox(width: 5),
                Text(
                  _latestPriceText,
                  style: AppTextStyles.num(12,
                      color: isDark ? AppColors.darkText : const Color(0xFF585858),
                      height: 1.3),
                ),
                const SizedBox(width: 5),
                Text(
                  _latestChangeRatioText,
                  style: AppTextStyles.num(
                    12,
                    color: _latestChangeRatio < 0
                        ? (isDark ? const Color(0xFF10B4A1) : const Color(0xFF1FA06D))
                        : (isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F)),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 重量 / 成交总价 / 日期 / 备注（gjs-form）
  Widget _buildForm(bool isDark) {
    final isBuy = _activeTab == 'buy';
    final textPrimary = isDark ? AppColors.darkText : const Color(0xFF333333);
    final borderColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFEF);
    return Padding(
      padding: const EdgeInsets.only(top: 11), // 22rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 黄金重量
          _buildInputGroup(
            isDark,
            label: isBuy ? '买入黄金重量' : '卖出黄金重量',
            controller: _goldWeightCtl,
            placeholder: _weightPlaceholder,
            unit: '克',
            borderColor: borderColor,
            textPrimary: textPrimary,
            helper: !isBuy && _holdingQuantity > 0
                ? _buildHelperText(isDark, '当前最多可卖出 ', _holdingQuantityText, ' 克')
                : null,
          ),
          // 成交总价
          _buildInputGroup(
            isDark,
            label: '成交总价',
            controller: _totalAmountCtl,
            placeholder: '请输入成交总价',
            prefix: '￥',
            unit: '元',
            borderColor: borderColor,
            textPrimary: textPrimary,
            helper: _averagePriceText != '--'
                ? _buildHelperText(isDark, '折合克价 ', _averagePriceText, ' 元/克')
                : null,
          ),
          // 日期选择
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openDatePopup,
            child: Container(
              margin: const EdgeInsets.only(top: 22), // 44rpx
              padding: const EdgeInsets.symmetric(vertical: 14), // 28rpx
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F4F4),
                      width: 1),
                  bottom: BorderSide(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F4F4),
                      width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBuy ? '买入日期' : '卖出日期',
                    style: AppTextStyles.cn(15,
                        color: isDark ? AppColors.darkText : const Color(0xFF313131),
                        height: 1.3),
                  ),
                  Row(
                    children: [
                      Text(_selectedDateLabel,
                          style: AppTextStyles.num(14, color: textPrimary)),
                      Padding(
                        padding: const EdgeInsets.only(left: 6), // 12rpx
                        child: Icon(Icons.arrow_drop_down,
                            size: 14,
                            color: isDark
                                ? AppColors.darkText
                                : const Color(0xFF333333)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 备注
          Padding(
            padding: const EdgeInsets.only(top: 17, bottom: 20), // 34rpx
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '备注',
                  style: AppTextStyles.cn(16,
                      color: isDark ? AppColors.darkText : const Color(0xFF303030),
                      height: 1.3),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 11), // 22rpx
                  constraints: const BoxConstraints(minHeight: 80), // 160rpx
                  padding: const EdgeInsets.all(11), // 22rpx
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282828) : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(9), // 18rpx
                  ),
                  child: TextField(
                    controller: _remarkCtl,
                    maxLength: 200,
                    maxLines: null,
                    onChanged: (_) => _onInputChanged(),
                    style: AppTextStyles.cn(14, color: textPrimary, height: 1.5),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                      hintText: '可填写购买渠道、金价说明等',
                      hintStyle: AppTextStyles.cn(14,
                          color: isDark
                              ? const Color(0xFF686E78)
                              : const Color(0xFFC8CBD3)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5), // 10rpx
                  child: Text(
                    '${_remarkCtl.text.length}/200',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.num(11,
                        color: isDark
                            ? const Color(0xFF686E78)
                            : const Color(0xFFC0BAB4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 辅助说明文字（gjs-form__helper，数字部分用 DIN 字体）
  Widget _buildHelperText(bool isDark, String before, String number, String after) {
    final color = isDark ? AppColors.darkTextSecondary : const Color(0xFFB7B0AA);
    return Text.rich(
      TextSpan(
        style: AppTextStyles.cn(12, color: color, height: 1.4),
        children: [
          TextSpan(text: before),
          TextSpan(text: number, style: AppTextStyles.num(12, color: color, height: 1.4)),
          TextSpan(text: after),
        ],
      ),
    );
  }

  /// 输入分组（gjs-form__group）
  Widget _buildInputGroup(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    required String placeholder,
    String? prefix,
    required String unit,
    required Color borderColor,
    required Color textPrimary,
    Widget? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 17), // 34rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTextStyles.cn(16,
                color: isDark ? AppColors.darkText : const Color(0xFF303030), height: 1.3),
          ),
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 10), // 24rpx 0 20rpx
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(prefix, style: AppTextStyles.num(16, color: textPrimary)),
                  ),
                Expanded(
                  child: SizedBox(
                    height: 35, // 70rpx
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _onInputChanged(),
                      style: AppTextStyles.num(20, color: textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: placeholder,
                        hintStyle: AppTextStyles.num(20,
                            color: isDark
                                ? const Color(0xFF686E78)
                                : const Color(0xFFDFE6F3)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(unit,
                      style: AppTextStyles.cn(14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF9D968F))),
                ),
              ],
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 7), // 14rpx
              child: helper,
            ),
        ],
      ),
    );
  }

  /// 底部固定提交栏（gjs-submit）
  Widget _buildSubmitBar(bool isDark) {
    final accent = isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F);
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: EdgeInsets.fromLTRB(
          15, 17, 15, 12 + MediaQuery.of(context).padding.bottom), // 34rpx 30rpx 24rpx+safe
      child: Column(
        children: [
          Text(
            '所有买入卖出均为模拟操作',
            style: AppTextStyles.cn(12,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB7B0AA),
                height: 1.4),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6), // 12rpx
            child: Text(
              '不会影响你的真实资金变动，仅用于记录贵金属持仓',
              textAlign: TextAlign.center,
              style: AppTextStyles.cn(12,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFFC5BEB7),
                  height: 1.45),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openConfirmPopup,
            child: Container(
              height: 48, // 96rpx
              margin: const EdgeInsets.only(top: 17), // 34rpx
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _submitting ? '提交中...' : '确定',
                style: AppTextStyles.cn(16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
