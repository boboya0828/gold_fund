import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import 'widgets/running_tab_confirm_dialog.dart';
import 'widgets/running_tab_wheel_picker.dart';

// TODO: 以下端点暂未收录进 ApiEndpoints，对齐 uni-app api/api.js 后建议迁入
// （getSymbolInfo / getAssetBySymbolId / assetRecordSearch / FundDca 系列）
class _RunningTabEndpoints {
  static const assetSymbolInfo = ApiEndpoints.assetSymbolInfo; // GET /{symbolId} — getSymbolInfo
  static const assetBySymbol = ApiEndpoints.assetBySymbol; // GET /{symbolId} — getAssetBySymbolId
  static const assetSymbolSearchOperate = ApiEndpoints.assetSymbolSearchOperate; // POST ?symbolId=
  static const fundDcaFeeEstimate = ApiEndpoints.fundDcaFeeEstimate; // POST
  static const fundDcaPlans = ApiEndpoints.fundDcaPlans; // GET 列表 / POST 创建
  static const fundDcaPlan = ApiEndpoints.fundDcaPlans; // PUT /{id}、POST /{id}/pause、/{id}/cancel
}

/// 日期选项 { label: '06月01日(周一)', value: '2024-06-01' }
class _DateOption {
  final String label;
  final String value;
  const _DateOption(this.label, this.value);
}

class _PlanDateOption extends _DateOption {
  final String weekText;
  const _PlanDateOption(super.label, super.value, this.weekText);
}

/// 交易流水页（加仓/减仓/定投/转换） — uni-app 对应: pages/index/fund/running-tab.vue
/// 入口：持仓详情页（position-details）“添加交易流水”按钮，携带
/// activeTab / uniqueSymbol / shortName / symbolId / assetId / bookId query 参数。
///
/// 平台专有能力未迁移：umeng 埋点（trackUmengEvent）。
class RunningTabPage extends StatefulWidget {
  final String activeTab; // buy / sell / plan / convert
  final String uniqueSymbol;
  final String shortName;
  final int? symbolId;
  final String assetId;
  final int bookId;

  const RunningTabPage({
    super.key,
    this.activeTab = 'buy',
    this.uniqueSymbol = '',
    this.shortName = '',
    this.symbolId,
    this.assetId = '',
    this.bookId = 0,
  });

  @override
  State<RunningTabPage> createState() => _RunningTabPageState();
}

class _RunningTabPageState extends State<RunningTabPage> {
  final ApiClient _api = ApiClient();

  // ===== Tab =====
  static const _tabList = [
    (label: '加仓', value: 'buy'),
    (label: '减仓', value: 'sell'),
    (label: '定投', value: 'plan'),
    (label: '转换', value: 'convert'),
  ];
  late String _activeTab = ['buy', 'sell', 'plan', 'convert'].contains(widget.activeTab)
      ? widget.activeTab
      : 'buy';
  bool get _isBuyOrSell => _activeTab == 'buy' || _activeTab == 'sell';

  // ===== 输入控制器 =====
  final _buyAmountCtl = TextEditingController();
  final _sellShareCtl = TextEditingController();
  final _feeRateCtl = TextEditingController(text: '0.15');
  final _sellFeeRateCtl = TextEditingController(text: '0.15');
  final _sellFeeAmountCtl = TextEditingController(text: '0.00');
  final _planAmountCtl = TextEditingController();
  final _planFeeRateCtl = TextEditingController(text: '0.120');
  final _convertOutAmountCtl = TextEditingController();
  final _convertInAmountCtl = TextEditingController();

  String _sellFeeMode = 'rate'; // rate | amount
  String _selectedSellRatio = '';
  String _convertInFundName = '';
  bool _noticeVisible = true;
  bool _submitting = false;

  // ===== 定投 =====
  bool _isPlanEditing = false;
  bool _planSubmitting = false;
  int? _editingDcaPlanId;
  double? _planFeeEstimateAmount;
  Timer? _dcaFeeTimer;
  List<Map<String, dynamic>> _dcaPlans = [];

  // ===== 标的 / 持仓 =====
  late final String _uniqueSymbol = widget.uniqueSymbol;
  late final String _shortName = widget.shortName;
  late final int? _symbolId = widget.symbolId;
  late final String _assetId = widget.assetId;
  late final int _bookId = widget.bookId;
  Map<String, dynamic> _symbolInfo = {};
  Map<String, dynamic> _positionInfo = {};

  // ===== 选项 =====
  static const _weekText = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  static const _longWeekText = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  static const _timeOptions = [
    (label: '下午3点前', value: 'before'),
    (label: '下午3点后', value: 'after'),
  ];
  static const _sellRatioOptions = ['1/4', '1/3', '1/2', '全部'];
  static const _planCycleOptions = [
    (label: '每日', value: 'daily'),
    (label: '每周', value: 'weekly'),
    (label: '每月', value: 'monthly'),
  ];
  static const _planWeekdayOptions = [
    (label: '周一', value: 1),
    (label: '周二', value: 2),
    (label: '周三', value: 3),
    (label: '周四', value: 4),
    (label: '周五', value: 5),
    (label: '周六', value: 6),
    (label: '周日', value: 7),
  ];
  static final _planMonthDayOptions = [
    for (var i = 1; i <= 31; i++) (label: '$i号', value: i),
  ];

  late final List<_DateOption> _dateOptions = _createDateOptions();
  late final List<_PlanDateOption> _planDateOptions = _createPlanDateOptions();
  late final List<_DateOption> _convertDateOptions = _createDateOptions();

  late int _selectedDateIndex = _dateOptions.length - 1;
  int _selectedTimeIndex = 0;
  int _selectedPlanCycleIndex = 0;
  int _selectedPlanWeekdayIndex = 0;
  int _selectedPlanMonthDayIndex = 0;
  int _selectedPlanDateIndex = 0;
  late int _selectedConvertDateIndex = _convertDateOptions.length - 1;

  // ===== 生命周期 =====

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _dcaFeeTimer?.cancel();
    _buyAmountCtl.dispose();
    _sellShareCtl.dispose();
    _feeRateCtl.dispose();
    _sellFeeRateCtl.dispose();
    _sellFeeAmountCtl.dispose();
    _planAmountCtl.dispose();
    _planFeeRateCtl.dispose();
    _convertOutAmountCtl.dispose();
    _convertInAmountCtl.dispose();
    super.dispose();
  }

  /// 源码 onLoad: 记录搜索 + 并行加载标的信息/持仓/定投计划
  Future<void> _init() async {
    if (_symbolId == null) return;
    unawaited(_recordSearchOperate());
    try {
      await Future.wait([_loadSymbolBaseInfo(), _loadPositionInfo(), _loadDcaPlans()]);
    } catch (_) {
      // 源码: console.error('交易页初始化失败')
    }
  }

  Future<void> _recordSearchOperate() async {
    try {
      // 源码: http.Post(`/asset/api/Symbol/searchOperate?symbolId=${symbolId}`)
      await _api.post('${_RunningTabEndpoints.assetSymbolSearchOperate}?symbolId=$_symbolId');
    } catch (_) {}
  }

  Future<void> _loadSymbolBaseInfo() async {
    if (_symbolId == null) return;
    final res = await _api.get('${_RunningTabEndpoints.assetSymbolInfo}/$_symbolId');
    final data = _unwrap(res);
    if (mounted) setState(() => _symbolInfo = data is Map ? data.cast<String, dynamic>() : {});
  }

  Future<void> _loadPositionInfo() async {
    if (_symbolId == null) return;
    final res = await _api.get('${_RunningTabEndpoints.assetBySymbol}/$_symbolId');
    final data = _unwrap(res);
    var list = <Map<String, dynamic>>[];
    if (data is Map && data['list'] is List) {
      list = (data['list'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (data is List) {
      list = data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    // 源码: 按 bookId 匹配持仓，无匹配回退第一条
    final matched = list.where((e) => _toInt(e['bookId']) == _bookId).firstOrNull;
    if (mounted) setState(() => _positionInfo = matched ?? (list.isNotEmpty ? list[0] : {}));
  }

  Future<void> _loadDcaPlans() async {
    try {
      final res = await _api.get(_RunningTabEndpoints.fundDcaPlans);
      final data = _unwrap(res);
      List raw = const [];
      if (data is List) {
        raw = data;
      } else if (data is Map && data['list'] is List) {
        raw = data['list'] as List;
      }
      if (mounted) {
        setState(() =>
            _dcaPlans = raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList());
      }
    } catch (_) {}
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
      return e.message ?? '请求失败';
    }
    return e.toString();
  }

  void _toast(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
    );
  }

  // ===== 日期选项（源码 createDateOptions / createPlanDateOptions） =====

  static int _jsDay(DateTime d) => d.weekday % 7; // JS getDay(): 0=周日

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String _formatDateText(DateTime d) =>
      '${_pad2(d.month)}月${_pad2(d.day)}日(${_weekText[_jsDay(d)]})';

  static String _formatDateValue(DateTime d) =>
      '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

  static String _formatPlanDateLabel(DateTime d) =>
      '${d.year}年${_pad2(d.month)}月${_pad2(d.day)}日';

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

  /// 下个周一开始的 8 个周一
  static List<_PlanDateOption> _createPlanDateOptions() {
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day);
    var daysToMonday = (8 - _jsDay(start)) % 7;
    if (daysToMonday == 0) daysToMonday = 7;
    start = start.add(Duration(days: daysToMonday));
    return [
      for (var i = 0; i < 8; i++)
        _PlanDateOption(
          _formatPlanDateLabel(start.add(Duration(days: i * 7))),
          _formatDateValue(start.add(Duration(days: i * 7))),
          _longWeekText[_jsDay(start.add(Duration(days: i * 7)))],
        ),
    ];
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

  double _toPositiveNumber(List<dynamic> values) {
    for (final v in values) {
      final n = _toNumber(v);
      if (n > 0) return n;
    }
    return 0;
  }

  String _formatDecimal(dynamic value, [int digits = 2]) {
    final n = _toNumber(value);
    return n.toStringAsFixed(digits);
  }

  /// 源码 formatMoneyText: toLocaleString('zh-CN', 两位小数)
  String _formatMoneyText(dynamic value, [int digits = 2]) {
    final n = _toNumber(value);
    final fixed = n.toStringAsFixed(digits);
    final parts = fixed.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  String _formatSignedPercent(dynamic value, [int digits = 2]) {
    final n = _toNumber(value);
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(digits)}%';
  }

  /// 源码 $utils.changeDateFormat(dateValue, 'YYYY-MM-DD')
  String _formatNetValueDate(dynamic dateValue) {
    if (dateValue == null) return '--';
    final dt = DateTime.tryParse(dateValue.toString());
    if (dt == null) return '--';
    return _formatDateValue(dt);
  }

  // ===== 计算属性（对齐源码 computed） =====

  String get _navbarTitle {
    if (_activeTab == 'plan') return '同步定投';
    if (_activeTab == 'convert') return '同步转换';
    return '添加交易流水';
  }

  Map<String, dynamic> get _latestPriceInfo =>
      _symbolInfo['latestPrice'] is Map
          ? (_symbolInfo['latestPrice'] as Map).cast<String, dynamic>()
          : {};

  Map<String, dynamic> get _latestNavInfo =>
      _latestPriceInfo['nav'] is Map
          ? (_latestPriceInfo['nav'] as Map).cast<String, dynamic>()
          : {};

  double get _unitPrice => _toPositiveNumber([
        _latestNavInfo['latestNav'],
        _latestPriceInfo['latestPrice'],
        _latestPriceInfo['close'],
        _latestPriceInfo['preClose'],
        _symbolInfo['netValue'],
        _symbolInfo['latestNetValue'],
        _positionInfo['curUnitPrice'],
        _positionInfo['netValue'],
        _positionInfo['costPrice'],
      ]);

  double get _latestChangeRatio => _toNumber(_latestPriceInfo['changeRatio'] ??
      _latestPriceInfo['chgRate'] ??
      _latestNavInfo['changeRatio'] ??
      _latestNavInfo['chgRate']);

  String get _fundName =>
      _shortName.isNotEmpty
          ? _shortName
          : (_symbolInfo['shortName'] ?? _symbolInfo['name'] ?? '--').toString();

  String get _fundCode =>
      (_symbolInfo['code'] ?? (_uniqueSymbol.isNotEmpty ? _uniqueSymbol : '--')).toString();

  String get _netValueDateText => _formatNetValueDate(
      _latestNavInfo['latestNavDate'] ?? _latestPriceInfo['latestTime'] ?? _symbolInfo['netValueDate']);

  String get _latestNetValueText =>
      _unitPrice > 0 ? _formatDecimal(_unitPrice, 4) : '--';

  String get _latestChangeRatioText => _formatSignedPercent(_latestChangeRatio, 2);

  double get _holdingQuantity =>
      _toNumber(_positionInfo['holdQuantity'] ?? _positionInfo['quantity']);

  String get _sellSharePlaceholder => _holdingQuantity > 0
      ? '最多可卖出${_holdingQuantity.toStringAsFixed(2)}份'
      : '请输入卖出份额';

  double get _serviceFee {
    if (_activeTab == 'buy') {
      return _round2(_toNumber(_buyAmountCtl.text) * _toNumber(_feeRateCtl.text) / 100);
    }
    if (_sellFeeMode == 'rate') {
      return _round2(
          _toNumber(_sellShareCtl.text) * _unitPrice * _toNumber(_sellFeeRateCtl.text) / 100);
    }
    return _round2(_toNumber(_sellFeeAmountCtl.text));
  }

  double get _sellAmount {
    final gross = _toNumber(_sellShareCtl.text) * _unitPrice;
    final net = gross - _serviceFee;
    return _round2(net > 0 ? net : 0);
  }

  double get _buyQuantity {
    final amount = _toNumber(_buyAmountCtl.text);
    final net = amount - _serviceFee;
    final netAmount = net > 0 ? net : 0.0;
    if (netAmount == 0 || _unitPrice <= 0) return 0;
    return _round4(netAmount / _unitPrice);
  }

  double get _planFeeValue =>
      _round2(_toNumber(_planAmountCtl.text) * _toNumber(_planFeeRateCtl.text) / 100);

  String get _planFeeAmount => _formatDecimal(_planFeeEstimateAmount ?? _planFeeValue, 2);

  bool get _canCompletePlan => _toNumber(_planAmountCtl.text) > 0;

  bool get _canCompleteConvert =>
      _toNumber(_convertOutAmountCtl.text) > 0 &&
      _toNumber(_convertInAmountCtl.text) > 0 &&
      _convertInFundName.isNotEmpty;

  double _round2(double v) => (v * 100).roundToDouble() / 100;

  double _round4(double v) => (v * 10000).roundToDouble() / 10000;

  // ===== 日期/时间选中项 =====

  String get _selectedDateLabel =>
      _selectedDateIndex >= 0 && _selectedDateIndex < _dateOptions.length
          ? _dateOptions[_selectedDateIndex].label
          : '';

  String get _selectedTimeLabel {
    final label = _timeOptions[_selectedTimeIndex].label;
    // 源码: 减仓时把「后」替换为「前」
    return _activeTab == 'sell' ? label.replaceAll('后', '前') : label;
  }

  int _clampIndex(int index, int length) =>
      index < 0 ? 0 : (index >= length ? length - 1 : index);

  ({String label, dynamic value}) get _selectedPlanCycle =>
      _planCycleOptions[_clampIndex(_selectedPlanCycleIndex, _planCycleOptions.length)];

  ({String label, int value}) get _selectedPlanWeekday =>
      _planWeekdayOptions[_clampIndex(_selectedPlanWeekdayIndex, _planWeekdayOptions.length)];

  ({String label, int value}) get _selectedPlanMonthDay =>
      _planMonthDayOptions[_clampIndex(_selectedPlanMonthDayIndex, _planMonthDayOptions.length)];

  _PlanDateOption get _selectedPlanDate =>
      _planDateOptions[_clampIndex(_selectedPlanDateIndex, _planDateOptions.length)];

  String get _selectedPlanPeriodLabel {
    final cycle = _selectedPlanCycle.value;
    if (cycle == 'daily') return '每日';
    if (cycle == 'monthly') return '每月${_selectedPlanMonthDay.label}';
    return '${_selectedPlanCycle.label} ${_selectedPlanWeekday.label}';
  }

  String _shortLabel(String value) {
    final parts = value.split('-');
    if (parts.length < 3) return '';
    return '${parts[1]}月${parts[2]}日';
  }

  String get _selectedPlanDateShortLabel => _shortLabel(_selectedPlanDate.value);

  _DateOption get _selectedConvertDate => _selectedConvertDateIndex >= 0 &&
          _selectedConvertDateIndex < _convertDateOptions.length
      ? _convertDateOptions[_selectedConvertDateIndex]
      : _convertDateOptions.last;

  String get _selectedConvertDateShortLabel => _shortLabel(_selectedConvertDate.value);

  // ===== 定投计划记录 =====

  Map<String, dynamic>? get _currentDcaPlan {
    for (final item in _dcaPlans) {
      if (_toInt(item['symbolId']) == _symbolId) return item;
    }
    return null;
  }

  bool get _hasPlanRecord => _currentDcaPlan != null;

  String _weekDayLabel(dynamic weekDay) {
    final v = _toInt(weekDay);
    for (final o in _planWeekdayOptions) {
      if (o.value == v) return o.label;
    }
    return '';
  }

  Map<String, String> get _planRecord {
    final item = _currentDcaPlan;
    if (item == null) {
      return {
        'totalAmount': '0.00',
        'periods': '0',
        'periodText': '',
        'amountText': '0.00',
        'nextDateText': '',
      };
    }
    final cycleType = _toInt(item['cycleType']);
    final cycleValue = cycleType == 2 ? 'weekly' : cycleType == 3 ? 'monthly' : 'daily';
    final periodText = cycleValue == 'daily'
        ? '每日'
        : cycleValue == 'monthly'
            ? '每月${item['monthDay'] ?? ''}号'
            : '每${_weekDayLabel(item['weekDay'])}';
    final nextRaw = item['nextExecuteDate'] ??
        item['nextInvestDate'] ??
        item['nextDate'] ??
        item['nextTradeDate'];
    final nextDt = nextRaw != null ? DateTime.tryParse(nextRaw.toString()) : null;
    return {
      'totalAmount': _formatMoneyText(
          item['totalAmount'] ?? item['totalInvestedAmount'] ?? item['accumulatedAmount'], 2),
      'periods': '${item['periods'] ?? item['executedPeriods'] ?? item['investedPeriods'] ?? 0}',
      'periodText': periodText,
      'amountText': _formatMoneyText(item['amount'], 2),
      'nextDateText': nextDt != null ? _formatPlanDateLabel(nextDt) : '',
    };
  }

  // ===== 确认弹窗文案 =====

  String get _confirmSellAmount => _formatDecimal(_sellAmount, 2);

  String get _confirmFeeAmount => '${_formatDecimal(_serviceFee, 2)}元';

  String get _confirmFeeRate => _activeTab == 'buy'
      ? '${_feeRateCtl.text.isEmpty ? '0' : _feeRateCtl.text}%'
      : (_sellFeeMode == 'rate'
          ? '${_sellFeeRateCtl.text.isEmpty ? '0' : _sellFeeRateCtl.text}%'
          : '${_formatDecimal(_serviceFee, 2)}元');

  String get _confirmTradeTime => '$_selectedDateLabel$_selectedTimeLabel';

  /// 源码 toTradeIsoString: 选中日期 + 10点(3点前)/16点(3点后)
  String _toTradeIsoString() {
    final value = _selectedDateIndex >= 0 && _selectedDateIndex < _dateOptions.length
        ? _dateOptions[_selectedDateIndex].value
        : _formatDateValue(DateTime.now());
    final p = value.split('-').map(int.parse).toList();
    final hour = _selectedTimeIndex == 0 ? 10 : 16;
    return DateTime(p[0], p[1], p[2], hour).toUtc().toIso8601String();
  }

  // ===== 交互：Tab / 输入 / 卖出比例 =====

  void _handleTradeTabClick(String value) {
    if (_activeTab == value) return;
    setState(() => _activeTab = value);
  }

  void _onInputChanged() => setState(() {});

  /// 源码 handleAmountInput('plan_amount') → 400ms 防抖估算定投手续费
  void _onPlanAmountChanged(String value) {
    setState(() {});
    _dcaFeeTimer?.cancel();
    final amount = _toNumber(value);
    if (amount <= 0 || _symbolId == null) {
      _planFeeEstimateAmount = null;
      return;
    }
    _dcaFeeTimer = Timer(const Duration(milliseconds: 400), () => _runDcaFeeEstimate(amount));
  }

  Future<void> _runDcaFeeEstimate(double amount) async {
    try {
      final res = await _api.post(_RunningTabEndpoints.fundDcaFeeEstimate,
          data: {'symbolId': _symbolId, 'amount': amount});
      final data = _unwrap(res);
      double fee = double.nan;
      if (data is Map) {
        fee = _toNumber(data['fee'] ?? data['serviceFee']);
      } else {
        fee = _toNumber(data);
      }
      if (mounted) setState(() => _planFeeEstimateAmount = fee.isFinite ? fee : null);
    } catch (_) {
      if (mounted) setState(() => _planFeeEstimateAmount = null);
    }
  }

  /// 源码 handleSellRatioClick
  void _handleSellRatioClick(String ratio) {
    if (_holdingQuantity == 0) return;
    const ratioMap = {'1/4': 0.25, '1/3': 1 / 3, '1/2': 0.5, '全部': 1.0};
    final multiple = ratioMap[ratio] ?? 0;
    if (multiple == 0) return;
    final quantity = ratio == '全部' ? _holdingQuantity : _holdingQuantity * multiple;
    final digits = ratio == '全部' ? 4 : 2;
    var fixed = quantity.toStringAsFixed(digits);
    // 源码: 去掉尾部多余的 0 和小数点
    if (fixed.contains('.')) {
      fixed = fixed.replaceAll(RegExp(r'0+$'), '');
      if (fixed.endsWith('.')) fixed = fixed.substring(0, fixed.length - 1);
    }
    setState(() {
      _selectedSellRatio = ratio;
      _sellShareCtl.text = fixed;
      _sellShareCtl.selection = TextSelection.collapsed(offset: fixed.length);
    });
  }

  void _toggleSellFeeMode() {
    setState(() => _sellFeeMode = _sellFeeMode == 'rate' ? 'amount' : 'rate');
  }

  // ===== 弹窗：买入/卖出时间 =====

  Future<void> _openTimePopup() async {
    final result = await RunningTabWheelPicker.show(
      context,
      title: _activeTab == 'buy' ? '买入时间' : '卖出时间',
      confirmText: '确定',
      pickerHeight: 250,
      initialIndexes: [_selectedDateIndex, _selectedTimeIndex],
      columnsBuilder: (_) => [
        [for (final o in _dateOptions) RunningTabPickerItem(o.label, o.value)],
        [for (final o in _timeOptions) RunningTabPickerItem(o.label, o.value)],
      ],
    );
    if (result != null) {
      setState(() {
        _selectedDateIndex = result[0];
        _selectedTimeIndex = result[1];
      });
    }
  }

  // ===== 弹窗：确认提交 =====

  /// 源码 openConfirmPopup（含校验）
  Future<void> _openConfirmPopup() async {
    if (_activeTab == 'buy') {
      if (_toNumber(_buyAmountCtl.text) == 0) return _toast('请输入买入金额');
      if (_unitPrice == 0) return _toast('暂无可用净值，无法计算买入份额');
      if (_buyQuantity == 0) return _toast('买入金额需大于手续费');
    }
    if (_activeTab == 'sell') {
      if (_toNumber(_sellShareCtl.text) == 0) return _toast('请输入卖出份额');
      if (_holdingQuantity > 0 && _toNumber(_sellShareCtl.text) > _holdingQuantity) {
        return _toast('卖出份额不能超过可卖数量');
      }
    }
    final confirmed = await RunningTabConfirmDialog.show(
      context,
      title: _activeTab == 'buy' ? '加仓确认' : '减仓确认',
      rows: [
        RunningTabConfirmRow('基金名称：', _fundName, numeric: false),
        if (_activeTab == 'buy')
          RunningTabConfirmRow(
              '买入金额：', '${_buyAmountCtl.text.isEmpty ? '0.00' : _buyAmountCtl.text} 元')
        else ...[
          RunningTabConfirmRow(
              '卖出份额：', '${_sellShareCtl.text.isEmpty ? '0.00' : _sellShareCtl.text} 份'),
          RunningTabConfirmRow('卖出金额：', '$_confirmSellAmount 元'),
        ],
        RunningTabConfirmRow('预估手续费：', _confirmFeeAmount),
        RunningTabConfirmRow(_activeTab == 'buy' ? '买入费率：' : '卖出费率：', _confirmFeeRate),
        RunningTabConfirmRow(_activeTab == 'buy' ? '买入日期：' : '卖出日期：', _confirmTradeTime),
      ],
    );
    if (confirmed) _handleConfirmSubmit();
  }

  /// 源码 handleConfirmSubmit: 提交买入/卖出
  Future<void> _handleConfirmSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final transactionTime = _toTradeIsoString();
      if (_activeTab == 'buy') {
        final totalAmount = _toNumber(_buyAmountCtl.text);
        if (totalAmount == 0) {
          _toast('请输入有效的买入金额');
          return;
        }
        if (_unitPrice == 0) {
          _toast('暂无可用净值，无法计算买入份额');
          return;
        }
        if (_buyQuantity == 0) {
          _toast('买入金额需大于手续费');
          return;
        }
        await _api.post(ApiEndpoints.assetBuy, data: {
          'bookId': _bookId,
          'symbolId': _symbolId,
          'quantity': _buyQuantity,
          'totalAmount': totalAmount,
          'serviceFee': _serviceFee,
          'transactionTime': transactionTime,
        });
      } else {
        final sellAssetId = _toInt(_assetId);
        if (sellAssetId == 0) {
          _toast('当前暂无可卖出的持仓');
          return;
        }
        final quantity = _round4(_toNumber(_sellShareCtl.text));
        if (quantity == 0 || _sellAmount == 0) {
          _toast('请输入有效的卖出份额');
          return;
        }
        await _api.post(ApiEndpoints.assetSell, data: {
          'assetId': sellAssetId,
          'quantity': quantity,
          'totalAmount': _sellAmount,
          'serviceFee': _serviceFee,
          'transactionTime': transactionTime,
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

  // ===== 定投 =====

  /// 源码 startPlanEdit
  void _startPlanEdit() {
    setState(() {
      _editingDcaPlanId = null;
      _planAmountCtl.text = '';
      _selectedPlanCycleIndex = 0;
      _selectedPlanWeekdayIndex = 0;
      _selectedPlanMonthDayIndex = 0;
      _isPlanEditing = true;
    });
  }

  /// 源码 startEditDcaPlan
  void _startEditDcaPlan() {
    final item = _currentDcaPlan;
    if (item == null) return;
    final planId = _toInt(item['planId'] ?? item['id']);
    final cycleType = _toInt(item['cycleType']);
    final cycleValue = cycleType == 2 ? 'weekly' : cycleType == 3 ? 'monthly' : 'daily';
    setState(() {
      _editingDcaPlanId = planId;
      _planAmountCtl.text = item['amount'] != null ? '${item['amount']}' : '';
      final cycleIndex = _planCycleOptions.indexWhere((o) => o.value == cycleValue);
      _selectedPlanCycleIndex = cycleIndex >= 0 ? cycleIndex : 0;
      if (cycleValue == 'weekly') {
        final idx = _planWeekdayOptions.indexWhere((o) => o.value == _toInt(item['weekDay']));
        _selectedPlanWeekdayIndex = idx >= 0 ? idx : 0;
      } else if (cycleValue == 'monthly') {
        final idx = _planMonthDayOptions.indexWhere((o) => o.value == _toInt(item['monthDay']));
        _selectedPlanMonthDayIndex = idx >= 0 ? idx : 0;
      }
      _isPlanEditing = true;
    });
  }

  /// 源码 completePlanSetup
  Future<void> _completePlanSetup() async {
    if (!_canCompletePlan) return _toast('请输入定投金额');
    final isEditing = _editingDcaPlanId != null;
    if (!isEditing && _symbolId == null) return _toast('缺少基金标的信息');
    if (_planSubmitting) return;
    setState(() => _planSubmitting = true);
    try {
      final cycleValue = _selectedPlanCycle.value;
      final cycleType = cycleValue == 'weekly' ? 2 : cycleValue == 'monthly' ? 3 : 1;
      final payload = <String, dynamic>{
        'bookId': _bookId,
        'amount': _toNumber(_planAmountCtl.text),
        'cycleType': cycleType,
        'weekDay': cycleValue == 'weekly' ? _selectedPlanWeekday.value : null,
        'monthDay': cycleValue == 'monthly' ? _selectedPlanMonthDay.value : null,
        'sourceType': 'SYNC',
      };
      if (isEditing) {
        await _api.put('${_RunningTabEndpoints.fundDcaPlan}/${_editingDcaPlanId!}',
            data: payload);
      } else {
        await _api.post(_RunningTabEndpoints.fundDcaPlans,
            data: {...payload, 'symbolId': _symbolId});
      }
      await _loadDcaPlans();
      if (!mounted) return;
      setState(() {
        _isPlanEditing = false;
        _editingDcaPlanId = null;
      });
      _toast(isEditing ? '定投计划已更新' : '定投计划已生成');
    } catch (e) {
      if (mounted) _toast(_errMsg(e));
    } finally {
      if (mounted) setState(() => _planSubmitting = false);
    }
  }

  /// 源码 openDcaPlanActions: uni.showActionSheet(['暂停', '修改', '删除'])
  Future<void> _openDcaPlanActions() async {
    if (_currentDcaPlan == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? const Color(0xFF202125) : Colors.white;
        final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in ['暂停', '修改', '删除'])
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).pop(item),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F2),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Text(item, style: AppTextStyles.cn(15, color: textColor)),
                    ),
                  ),
                Container(height: 6, color: isDark ? const Color(0xFF111315) : const Color(0xFFF7F7F7)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Text('取消', style: AppTextStyles.cn(15, color: textColor)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == '暂停') {
      _pauseCurrentDcaPlan();
    } else if (action == '修改') {
      _startEditDcaPlan();
    } else if (action == '删除') {
      _deleteCurrentDcaPlan();
    }
  }

  /// 源码 uni.showModal 二次确认
  Future<bool> _confirmPlanAction(String title, String content) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
        title: Text(title,
            style: AppTextStyles.cn(16,
                color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))),
        content: Text(content,
            style: AppTextStyles.cn(14,
                color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF555555))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style: AppTextStyles.cn(14,
                    color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('确定', style: AppTextStyles.cn(14, color: const Color(0xFFE85F6F))),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 源码 pauseCurrentDcaPlan
  Future<void> _pauseCurrentDcaPlan() async {
    final plan = _currentDcaPlan;
    if (plan == null) return;
    final planId = _toInt(plan['planId'] ?? plan['id']);
    if (planId == 0) return;
    final ok = await _confirmPlanAction('暂停定投', '确定要暂停当前定投计划吗？');
    if (!ok) return;
    try {
      await _api.post('${_RunningTabEndpoints.fundDcaPlan}/$planId/pause');
      await _loadDcaPlans();
      if (mounted) _toast('定投计划已暂停');
    } catch (e) {
      if (mounted) _toast(_errMsg(e));
    }
  }

  /// 源码 deleteCurrentDcaPlan
  Future<void> _deleteCurrentDcaPlan() async {
    final plan = _currentDcaPlan;
    if (plan == null) return;
    final planId = _toInt(plan['planId'] ?? plan['id']);
    final ok = await _confirmPlanAction('删除定投', '确定要删除当前定投计划吗？');
    if (!ok || planId == 0) return;
    try {
      await _api.post('${_RunningTabEndpoints.fundDcaPlan}/$planId/cancel');
      await _loadDcaPlans();
      if (mounted) _toast('定投计划已删除');
    } catch (e) {
      if (mounted) _toast(_errMsg(e));
    }
  }

  /// 源码 openPlanPeriodPopup（周期 + 周一~周日/1~31号 双列联动）
  Future<void> _openPlanPeriodPopup() async {
    final secondInitial = _selectedPlanCycle.value == 'monthly'
        ? _selectedPlanMonthDayIndex
        : _selectedPlanWeekdayIndex;
    final result = await RunningTabWheelPicker.show(
      context,
      title: '定投周期',
      pickerHeight: 230,
      initialIndexes: [_selectedPlanCycleIndex, secondInitial],
      columnsBuilder: (selected) {
        final cycle = _planCycleOptions[_clampIndex(selected[0], _planCycleOptions.length)].value;
        final List<({String label, int value})> second;
        if (cycle == 'weekly') {
          second = _planWeekdayOptions;
        } else if (cycle == 'monthly') {
          second = _planMonthDayOptions;
        } else {
          second = const [];
        }
        return [
          [for (final o in _planCycleOptions) RunningTabPickerItem(o.label, o.value)],
          [for (final o in second) RunningTabPickerItem(o.label, '${o.value}')],
        ];
      },
    );
    if (result != null) {
      setState(() {
        _selectedPlanCycleIndex = result[0];
        final cycle = _planCycleOptions[_clampIndex(result[0], _planCycleOptions.length)].value;
        if (cycle == 'monthly') {
          _selectedPlanMonthDayIndex = _clampIndex(result[1], _planMonthDayOptions.length);
        } else if (cycle == 'weekly') {
          _selectedPlanWeekdayIndex = _clampIndex(result[1], _planWeekdayOptions.length);
        }
      });
    }
  }

  /// 源码 openPlanDatePopup（下次定投时间：8 个周一）
  Future<void> _openPlanDatePopup() async {
    final result = await RunningTabWheelPicker.show(
      context,
      title: '定投时间',
      pickerHeight: 230,
      initialIndexes: [_selectedPlanDateIndex],
      columnsBuilder: (_) => [
        [for (final o in _planDateOptions) RunningTabPickerItem(o.label, o.value)],
      ],
    );
    if (result != null) setState(() => _selectedPlanDateIndex = result[0]);
  }

  // ===== 转换 =====

  /// 源码 selectConvertInFund（占位实现：无基金选择页，直接填模拟值）
  void _selectConvertInFund() {
    setState(() {
      if (_convertInFundName.isEmpty) _convertInFundName = '模拟转入基金';
    });
    _toast('已选择模拟转入基金', seconds: 2);
  }

  Future<void> _openConvertDatePopup() async {
    final result = await RunningTabWheelPicker.show(
      context,
      title: '转换日期',
      pickerHeight: 230,
      initialIndexes: [_selectedConvertDateIndex],
      columnsBuilder: (_) => [
        [for (final o in _convertDateOptions) RunningTabPickerItem(o.label, o.value)],
      ],
    );
    if (result != null) setState(() => _selectedConvertDateIndex = result[0]);
  }

  /// 源码 completeConvertSetup（纯前端校验 + 提示，无接口提交）
  void _completeConvertSetup() {
    if (_toNumber(_convertOutAmountCtl.text) == 0) return _toast('请输入转出金额');
    if (_convertInFundName.isEmpty) return _toast('请选择转入基金');
    if (_toNumber(_convertInAmountCtl.text) == 0) return _toast('请输入转入金额');
    _toast('转换记录已同步');
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
        title: _navbarTitle,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: isDark ? AppColors.darkText : AppColors.lightText,
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
                  if (_activeTab != 'convert') _buildFundCard(isDark),
                  if (_activeTab == 'plan') _buildPlanContent(isDark),
                  if (_activeTab == 'convert') _buildConvertContent(isDark),
                  if (_isBuyOrSell)
                    Container(
                      margin: const EdgeInsets.only(top: 30),
                      height: 15,
                      color: isDark ? AppColors.darkBg : const Color(0xFFF1F1F3),
                    ),
                ],
              ),
            ),
          ),
          if (_isBuyOrSell) _buildTradeBottomBar(isDark),
          if (_activeTab == 'plan' && _isPlanEditing) _buildPlanBottomBar(isDark),
          if (_activeTab == 'convert') _buildConvertBottomBar(isDark),
        ],
      ),
    );
  }

  /// 顶部 加仓/减仓/定投/转换 tab（page-grid-title）
  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 44,
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
                onTap: () => _handleTradeTabClick(item.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.cn(
                        16,
                        color: _activeTab == item.value
                            ? (isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F))
                            : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFCFC9C1)),
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (_activeTab == item.value)
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 30,
                          height: 2,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F),
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

  /// 基金信息卡 + 买入/卖出表单（page-grid-from）
  Widget _buildFundCard(bool isDark) {
    final isPlan = _activeTab == 'plan';
    return Container(
      padding: isPlan
          ? const EdgeInsets.fromLTRB(20, 14, 20, 15)
          : const EdgeInsets.fromLTRB(12, 14, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: isPlan && !isDark
            ? const [BoxShadow(color: Color(0x0A233152), blurRadius: 9, offset: Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 基金名称 + 代码
          RichText(
            text: TextSpan(
              style: AppTextStyles.cn(16,
                  color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.25),
              children: [
                TextSpan(text: _fundName),
                TextSpan(
                  text: ' $_fundCode',
                  style: AppTextStyles.num(14,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF7F7F7F)),
                ),
              ],
            ),
          ),
          // 最新净值
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('最新净值（', style: AppTextStyles.cn(12, color: _metaColor(isDark), height: 1.3)),
                Text(_netValueDateText,
                    style: AppTextStyles.num(12, color: _metaColor(isDark), height: 1.3)),
                Text('）', style: AppTextStyles.cn(12, color: _metaColor(isDark), height: 1.3)),
                const SizedBox(width: 5),
                Text(_latestNetValueText,
                    style: AppTextStyles.num(12,
                        color: isDark ? AppColors.darkText : const Color(0xFF585858), height: 1.3)),
                const SizedBox(width: 5),
                Text(
                  _latestChangeRatioText,
                  style: AppTextStyles.num(12,
                      color: _latestChangeRatio < 0
                          ? (isDark ? const Color(0xFF10B4A1) : const Color(0xFF1FA06D))
                          : (isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F)),
                      height: 1.3),
                ),
              ],
            ),
          ),
          if (_isBuyOrSell) ..._buildTradeForm(isDark),
        ],
      ),
    );
  }

  Color _metaColor(bool isDark) =>
      isDark ? AppColors.darkTextSecondary : const Color(0xFFB4B4B4);

  /// 买入金额/卖出份额 + 手续费 + 时间选择
  List<Widget> _buildTradeForm(bool isDark) {
    final isBuy = _activeTab == 'buy';
    final textPrimary = isDark ? AppColors.darkText : const Color(0xFF333333);
    return [
      // 金额/份额输入
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isBuy ? '买入金额' : '卖出份额',
                style: AppTextStyles.cn(16,
                    color: isDark ? AppColors.darkText : const Color(0xFF303030), height: 1.3)),
            Container(
              padding: const EdgeInsets.only(top: 14, bottom: 11),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFEF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (isBuy)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('￥', style: AppTextStyles.num(16, color: textPrimary)),
                    ),
                  Expanded(
                    child: TextField(
                      controller: isBuy ? _buyAmountCtl : _sellShareCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _onInputChanged(),
                      style: AppTextStyles.num(isBuy ? 20 : 18, color: textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: isBuy ? '请输入买入金额' : _sellSharePlaceholder,
                        // 源码浅色 placeholder: #DFE6F3 / 卖出 #D9E1F0
                        hintStyle: AppTextStyles.num(isBuy ? 20 : 18,
                            color: isDark
                                ? const Color(0xFF686E78)
                                : (isBuy ? const Color(0xFFDFE6F3) : const Color(0xFFD9E1F0))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 卖出比例快捷选项
            if (!isBuy)
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Row(
                  children: [
                    for (var i = 0; i < _sellRatioOptions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _handleSellRatioClick(_sellRatioOptions[i]),
                          child: Container(
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedSellRatio == _sellRatioOptions[i]
                                  ? (isDark ? const Color(0x24E05665) : const Color(0xFFFFF4F5))
                                  : (isDark ? const Color(0xFF282828) : Colors.white),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _selectedSellRatio == _sellRatioOptions[i]
                                    ? const Color(0xFFE05665)
                                    : (isDark ? const Color(0xFF34363D) : const Color(0xFFDDDDDD)),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _sellRatioOptions[i],
                              style: AppTextStyles.num(
                                14,
                                color: _selectedSellRatio == _sellRatioOptions[i]
                                    ? const Color(0xFFE05665)
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF3B3B3B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      // 手续费行
      _buildFeeRow(isDark, isBuy),
      // 时间选择行
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isBuy ? '买入时间' : '卖出时间',
                style: AppTextStyles.cn(14,
                    color: isDark ? AppColors.darkText : const Color(0xFF313131), height: 1.3)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openTimePopup,
              child: Row(
                children: [
                  Text('$_selectedDateLabel $_selectedTimeLabel',
                      style: AppTextStyles.cn(14, color: textPrimary)),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.arrow_drop_down,
                        size: 14,
                        color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// 手续费行（买入: 估算手续费xx元（买入费率[input]%）；卖出: 卖出费率/费用 可切换）
  Widget _buildFeeRow(bool isDark, bool isBuy) {
    final accent = isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F);
    final muted = isDark ? AppColors.darkTextSecondary : const Color(0xFF919191);
    if (isBuy) {
      return Padding(
        padding: const EdgeInsets.only(top: 13, bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('估算手续费', style: AppTextStyles.cn(12, color: muted, height: 1.2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(_confirmFeeAmount, style: AppTextStyles.num(16, color: accent)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('（买入费率', style: AppTextStyles.cn(12, color: muted, height: 1.2)),
            ),
            _feeRateInput(_feeRateCtl, isDark, width: 56, fontSize: 14),
            Text('%）',
                style: AppTextStyles.cn(15,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB8B1AA),
                    height: 1.1)),
          ],
        ),
      );
    }
    // 卖出
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 19),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_sellFeeMode == 'rate' ? '卖出费率' : '卖出费用',
              style: AppTextStyles.cn(14, color: accent, height: 1.2)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleSellFeeMode,
            child: Padding(
              padding: const EdgeInsets.only(left: 5, right: 6),
              child: Icon(AppIcons.switchIcon,
                  size: 18, color: isDark ? const Color(0xFF686E78) : const Color(0xFF919191)),
            ),
          ),
          _feeRateInput(
            _sellFeeMode == 'rate' ? _sellFeeRateCtl : _sellFeeAmountCtl,
            isDark,
            width: 42,
            fontSize: 16,
            key: ValueKey(_sellFeeMode),
          ),
          Text(_sellFeeMode == 'rate' ? '%' : '元',
              style: AppTextStyles.cn(15, color: accent, height: 1.1)),
        ],
      ),
    );
  }

  /// 下划线费率输入框（page-grid-from__fee-rate）
  Widget _feeRateInput(TextEditingController controller, bool isDark,
      {required double width, required double fontSize, Key? key}) {
    final accent = isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F);
    return Container(
      key: key,
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: accent, width: 1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onChanged: (_) => _onInputChanged(),
        style: AppTextStyles.num(fontSize, color: accent),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.only(bottom: 2),
        ),
      ),
    );
  }

  /// 底部固定提交栏（page-grid-seve）
  Widget _buildTradeBottomBar(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: EdgeInsets.fromLTRB(15, 17, 15, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('手动操作太麻烦？ 试试',
                  style: AppTextStyles.cn(12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB7B0AA),
                      height: 1.4)),
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text('识图批量加仓',
                    style: AppTextStyles.cn(12,
                        color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F),
                        height: 1.4)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('所有加仓减仓均为模拟操作，不会影响你的真实资金变动',
                textAlign: TextAlign.center,
                style: AppTextStyles.cn(12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFFC5BEB7),
                    height: 1.45)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openConfirmPopup,
            child: Container(
              height: 48,
              margin: const EdgeInsets.only(top: 17),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_submitting ? '提交中...' : '确定',
                  style: AppTextStyles.cn(16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 定投内容 =====

  Widget _buildPlanContent(bool isDark) {
    if (!_hasPlanRecord && !_isPlanEditing) return _buildPlanEmpty(isDark);
    if (_isPlanEditing) return _buildPlanForm(isDark);
    return _buildPlanList(isDark);
  }

  /// 暂无定投计划（plan-empty）
  Widget _buildPlanEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 180, 15, 0),
      child: Column(
        children: [
          Text('暂无定投计划',
              style: AppTextStyles.cn(14,
                  color: isDark ? const Color(0xFF686E78) : const Color(0xFFC9C9C9), height: 1.4)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startPlanEdit,
            child: Container(
              height: 52,
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x29E05665) : const Color(0xFFFDECEF),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: Text('+',
                        style: AppTextStyles.cn(21,
                            color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F),
                            weight: FontWeight.w600)),
                  ),
                  Text('添加定投计划',
                      style: AppTextStyles.cn(15,
                          color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 定投表单（plan-form）
  Widget _buildPlanForm(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final shadow = isDark
        ? null
        : const [BoxShadow(color: Color(0x09233152), blurRadius: 9, offset: Offset(0, 4))];
    final labelColor = isDark ? AppColors.darkText : const Color(0xFF1E2238);
    final subColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8F96A6);
    return Column(
      children: [
        // 同步定投金额卡
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(20, 17, 20, 14),
          decoration: BoxDecoration(color: cardBg, boxShadow: shadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('同步定投金额', style: AppTextStyles.cn(16, color: labelColor, height: 1.35)),
              Container(
                height: 53,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F1F5),
                        width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('￥',
                          style: AppTextStyles.num(16,
                              color: isDark ? AppColors.darkText : const Color(0xFF101428))),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _planAmountCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: _onPlanAmountChanged,
                        style: AppTextStyles.num(20,
                            color: isDark ? AppColors.darkText : const Color(0xFF101428)),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '输入已定投金额',
                          hintStyle: AppTextStyles.num(20,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFFCFCFCF)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 估算手续费行
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Text('估算手续费', style: AppTextStyles.cn(12, color: subColor, height: 1.4)),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(_planFeeAmount,
                          style: AppTextStyles.num(12,
                              color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F))),
                    ),
                    Text('元（买入费率', style: AppTextStyles.cn(12, color: subColor, height: 1.4)),
                    Container(
                      width: 60,
                      height: 21,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: isDark ? const Color(0xFF34363D) : const Color(0xFFC8CDD8),
                              width: 1),
                        ),
                      ),
                      child: TextField(
                        controller: _planFeeRateCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (_) => _onInputChanged(),
                        style: AppTextStyles.num(14,
                            color: isDark ? AppColors.darkText : const Color(0xFF7C8DA8)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Text('%）', style: AppTextStyles.cn(12, color: subColor, height: 1.4)),
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(left: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark ? const Color(0xFF50545D) : const Color(0xFFC7C7C7),
                            width: 1),
                      ),
                      child: Text('?',
                          style: AppTextStyles.cn(12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFFB7B7B7))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 周期/时间选择卡
        Container(
          margin: const EdgeInsets.only(top: 9, bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: cardBg, boxShadow: shadow),
          child: Column(
            children: [
              _planFormRow(
                isDark,
                label: '原平台定投周期：',
                value: _selectedPlanPeriodLabel,
                showBorder: true,
                onTap: _openPlanPeriodPopup,
              ),
              _planFormRow(
                isDark,
                label: '下次定投时间：',
                value: _selectedPlanDateShortLabel,
                showBorder: false,
                onTap: _openPlanDatePopup,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planFormRow(bool isDark,
      {required String label,
      required String value,
      required bool showBorder,
      required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEF0F5), width: 1))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppTextStyles.cn(14,
                    color: isDark ? AppColors.darkText : const Color(0xFF1E2238), height: 1.3)),
            Row(
              children: [
                Text(value,
                    style: AppTextStyles.cn(14,
                        color: isDark ? AppColors.darkText : const Color(0xFF161A30))),
                Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Icon(Icons.calendar_month,
                      size: 22,
                      color: isDark ? const Color(0xFF686E78) : const Color(0xFFB8BDC6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 定投计划卡片列表（plan-list）
  Widget _buildPlanList(bool isDark) {
    final record = _planRecord;
    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFF7F8FC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openDcaPlanActions,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 13),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: isDark
                    ? null
                    : const [
                        BoxShadow(color: Color(0x09233152), blurRadius: 9, offset: Offset(0, 4))
                      ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month,
                              size: 23,
                              color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF202124)),
                          const SizedBox(width: 7),
                          Text('定投计划',
                              style: AppTextStyles.cn(16,
                                  color: isDark ? AppColors.darkText : const Color(0xFF1E2238),
                                  height: 1.35)),
                        ],
                      ),
                      Text('进行中',
                          style: AppTextStyles.cn(14,
                              color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F),
                              height: 1.4)),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEF0F5),
                            width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('累计定投(元)',
                                style: AppTextStyles.cn(13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF9297A1),
                                    height: 1.35)),
                            Padding(
                              padding: const EdgeInsets.only(top: 11),
                              child: Text(record['totalAmount']!,
                                  style: AppTextStyles.num(23,
                                      color: isDark
                                          ? AppColors.darkText
                                          : const Color(0xFF111111),
                                      weight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('已投期数',
                                style: AppTextStyles.cn(13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF9297A1),
                                    height: 1.35)),
                            Padding(
                              padding: const EdgeInsets.only(top: 11),
                              child: Text(record['periods']!,
                                  style: AppTextStyles.num(23,
                                      color: isDark
                                          ? AppColors.darkText
                                          : const Color(0xFF111111),
                                      weight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Text('${record['periodText']}定投',
                            style: AppTextStyles.cn(14,
                                color: isDark ? AppColors.darkText : const Color(0xFF202124),
                                height: 1.4)),
                        Text(record['amountText']!,
                            style: AppTextStyles.num(14,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF9AA0AA),
                                height: 1.4)),
                        Text('元',
                            style: AppTextStyles.cn(14,
                                color: isDark ? AppColors.darkText : const Color(0xFF202124),
                                height: 1.4)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('下次转入时间：${record['nextDateText']}',
                        style: AppTextStyles.cn(13,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9AA0AA),
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startPlanEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                      color: isDark ? AppColors.darkBg : const Color(0xFFF7F8FC), width: 6),
                ),
              ),
              child: Text('+ 添加定投计划',
                  style: AppTextStyles.cn(15,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9AA0AA),
                      height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }

  /// 定投底部提交栏（plan-submit）
  Widget _buildPlanBottomBar(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: EdgeInsets.fromLTRB(15, 15, 15, 12 + MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _completePlanSetup,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _canCompletePlan
                ? (isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F))
                : (isDark ? const Color(0x29E05665) : const Color(0xFFFDECEF)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(_planSubmitting ? '提交中...' : '完成设置',
              style: AppTextStyles.cn(16,
                  color: _canCompletePlan || !isDark ? Colors.white : const Color(0x9EFFFFFF))),
        ),
      ),
    );
  }

  // ===== 转换内容 =====

  Widget _buildConvertContent(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final shadow = isDark
        ? null
        : const [BoxShadow(color: Color(0x09233152), blurRadius: 9, offset: Offset(0, 4))];
    return Container(
      color: isDark ? AppColors.darkBg : Colors.white,
      child: Column(
        children: [
          // 转出基金 / 同步转出金额
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: cardBg, boxShadow: shadow),
            child: Column(
              children: [
                _convertRow(isDark,
                    label: '转出基金',
                    showBorder: true,
                    child: Text(_fundName,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.cn(15,
                            color: isDark ? AppColors.darkText : const Color(0xFF1F2541),
                            weight: FontWeight.w600))),
                _convertRow(isDark,
                    label: '同步转出金额',
                    showBorder: false,
                    child: _convertInput(_convertOutAmountCtl, '请输入对应已转出金额', isDark)),
              ],
            ),
          ),
          // 转入基金 / 同步转入金额
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: cardBg, boxShadow: shadow),
            child: Column(
              children: [
                _convertRow(isDark,
                    label: '转入基金',
                    showBorder: true,
                    onTap: _selectConvertInFund,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _convertInFundName.isEmpty ? '请选择已转入基金' : _convertInFundName,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cn(15,
                                color: _convertInFundName.isEmpty
                                    ? (isDark ? const Color(0xFF686E78) : const Color(0xFFCFCFCF))
                                    : (isDark ? AppColors.darkText : const Color(0xFF1E2238))),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20,
                            color: isDark ? const Color(0xFF686E78) : const Color(0xFFD0D0D0)),
                      ],
                    )),
                _convertRow(isDark,
                    label: '同步转入金额',
                    showBorder: false,
                    child: _convertInput(_convertInAmountCtl, '请输入对应已转入金额', isDark)),
              ],
            ),
          ),
          // 原平台转换日期
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: cardBg, boxShadow: shadow),
            child: _convertRow(isDark,
                label: '原平台转换日期：',
                showBorder: false,
                onTap: _openConvertDatePopup,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_selectedConvertDateShortLabel,
                        style: AppTextStyles.cn(15,
                            color: isDark ? AppColors.darkText : const Color(0xFF1E2238))),
                    const SizedBox(width: 5),
                    Icon(Icons.calendar_month,
                        size: 22,
                        color: isDark ? const Color(0xFF686E78) : const Color(0xFF606266)),
                  ],
                )),
          ),
          // 教程提示（源码无点击事件）
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('不知道怎么填写？',
                    style: AppTextStyles.cn(13,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8D9099),
                        height: 1.4)),
                Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Text('点击查看教程',
                      style: AppTextStyles.cn(13,
                          color: isDark ? const Color(0xFFE05665) : const Color(0xFF506EB7),
                          weight: FontWeight.w600,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _convertRow(bool isDark,
      {required String label, required Widget child, required bool showBorder, VoidCallback? onTap}) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
                bottom: BorderSide(
                    color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEF0F5), width: 1))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 125,
            child: Text(label,
                style: AppTextStyles.cn(15,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF5E6472),
                    height: 1.35)),
          ),
          Expanded(child: child),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }

  Widget _convertInput(TextEditingController controller, String hint, bool isDark) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      onChanged: (_) => _onInputChanged(),
      style: AppTextStyles.num(15, color: isDark ? AppColors.darkText : const Color(0xFF1E2238)),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle:
            AppTextStyles.num(15, color: isDark ? const Color(0xFF686E78) : const Color(0xFFCFCFCF)),
      ),
    );
  }

  /// 转换底部提交栏（convert-submit）
  Widget _buildConvertBottomBar(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: EdgeInsets.fromLTRB(15, 15, 15, 12 + MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _completeConvertSetup,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _canCompleteConvert
                ? (isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F))
                : (isDark ? const Color(0x29E05665) : const Color(0xFFFDECEF)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text('完成',
              style: AppTextStyles.cn(16,
                  color: _canCompleteConvert || !isDark ? Colors.white : const Color(0x9EFFFFFF))),
        ),
      ),
    );
  }
}
