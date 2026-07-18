import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'madd_number_keyboard.dart';

/// 手动批量录入持仓 — 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/mass-upload-madd.vue)
/// 基金(走搜索选择) + 贵金属(固定4项下拉) 混合批量录入, 支持收起/展开, 数字键盘输入
class MassUploadMaddPage extends StatefulWidget {
  final String? bookId;
  final String? uniqueSymbol;
  final String? shortName;
  final String? symbolId;
  final String? assetAmount;
  final String? profitAmount;

  const MassUploadMaddPage({
    super.key,
    this.bookId,
    this.uniqueSymbol,
    this.shortName,
    this.symbolId,
    this.assetAmount,
    this.profitAmount,
  });

  @override
  State<MassUploadMaddPage> createState() => _MassUploadMaddPageState();
}

// ===== 内联数据模型 (对齐 vue 中的 entry 结构) =====
class _FundEntry {
  final String key;
  String shortName;
  String uniqueSymbol;
  int? symbolId;
  double? latestPrice;
  String amount;
  String profit;
  bool collapsed;

  _FundEntry({
    required this.key,
    this.shortName = '',
    this.uniqueSymbol = '',
    this.symbolId,
    this.latestPrice,
    this.amount = '',
    this.profit = '',
    this.collapsed = false,
  });
}

class _MetalEntry {
  final String key;
  final LayerLink link = LayerLink();
  String shortName;
  String uniqueSymbol;
  int? symbolId;
  String amount;
  String costPrice;
  bool collapsed;

  _MetalEntry({
    required this.key,
    this.shortName = '',
    this.uniqueSymbol = '',
    this.symbolId,
    this.amount = '',
    this.costPrice = '',
    this.collapsed = false,
  });
}

class _MetalOption {
  final String shortName;
  final int symbolId;
  const _MetalOption(this.shortName, this.symbolId);
}

class _KeyboardTarget {
  final String type; // 'fund' | 'metal'
  final String key;
  final String field; // 'amount' | 'profit' | 'costPrice'
  const _KeyboardTarget(this.type, this.key, this.field);
}

class _MassUploadMaddPageState extends State<MassUploadMaddPage> {
  final ApiClient _api = ApiClient();

  String? _bookId;
  bool _saving = false;
  final List<_FundEntry> _fundEntries = [];
  final List<_MetalEntry> _metalEntries = [];
  String _activeMetalDropdownKey = '';
  OverlayEntry? _metalDropdownOverlay;
  final Map<String, Map<String, String>> _entryErrors = {};
  bool _numberKeyboardVisible = false;
  _KeyboardTarget? _numberKeyboardTarget;
  int _entrySeed = 0;

  static const _metalOptions = [
    _MetalOption('选胜黄金', 1032768),
    _MetalOption('选胜白银', 1032769),
    _MetalOption('选胜铂金', 1032770),
    _MetalOption('选胜钯金', 1032771),
  ];

  @override
  void initState() {
    super.initState();
    // onLoad: 带持仓参数则预填第一条基金, 否则新建一条空基金
    _bookId = widget.bookId;
    final uniqueSymbol = widget.uniqueSymbol ?? '';
    final shortName = widget.shortName ?? '';
    final symbolId = int.tryParse(widget.symbolId ?? '');
    final assetAmount = widget.assetAmount ?? '';
    final profitAmount = widget.profitAmount ?? '';
    if (uniqueSymbol.isNotEmpty || shortName.isNotEmpty || assetAmount.isNotEmpty || profitAmount.isNotEmpty) {
      _appendFundEntry(payload: _FundEntry(
        key: '',
        uniqueSymbol: uniqueSymbol,
        shortName: shortName,
        symbolId: symbolId,
        amount: assetAmount,
        profit: profitAmount,
      ));
    } else {
      _appendFundEntry();
    }
  }

  @override
  void dispose() {
    _removeMetalDropdown();
    super.dispose();
  }

  // ===== 工具 =====
  bool get _hasBookId => _bookId != null && _bookId!.isNotEmpty;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  static String _normalizeSignedDecimalInput(String value) {
    final isNegative = value.trimLeft().startsWith('-');
    final numeric = value.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '${isNegative ? '-' : ''}$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  static String _normalizePositiveDecimalInput(String value) {
    final numeric = value.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  // ===== entry 工厂/判定 =====
  _FundEntry _createFundEntry({_FundEntry? payload}) => _FundEntry(
        key: 'fund-${_entrySeed++}',
        shortName: payload?.shortName ?? '',
        uniqueSymbol: payload?.uniqueSymbol ?? '',
        symbolId: payload?.symbolId,
        latestPrice: payload?.latestPrice,
        amount: payload?.amount ?? '',
        profit: payload?.profit ?? '',
        collapsed: payload?.collapsed ?? false,
      );

  _MetalEntry _createMetalEntry({_MetalEntry? payload}) => _MetalEntry(
        key: 'metal-${_entrySeed++}',
        shortName: payload?.shortName ?? '',
        uniqueSymbol: payload?.uniqueSymbol ?? '',
        symbolId: payload?.symbolId,
        amount: payload?.amount ?? '',
        costPrice: payload?.costPrice ?? '',
        collapsed: payload?.collapsed ?? false,
      );

  bool _isFundEntryComplete(_FundEntry item) =>
      item.uniqueSymbol.isNotEmpty && item.amount.isNotEmpty && item.profit.isNotEmpty;

  bool _isMetalEntryComplete(_MetalEntry item) =>
      item.uniqueSymbol.isNotEmpty && item.amount.isNotEmpty && item.costPrice.isNotEmpty;

  bool _isFundEntryEmpty(_FundEntry item) =>
      item.shortName.isEmpty && item.uniqueSymbol.isEmpty && item.symbolId == null && item.amount.isEmpty && item.profit.isEmpty;

  bool _isMetalEntryEmpty(_MetalEntry item) =>
      item.shortName.isEmpty && item.uniqueSymbol.isEmpty && item.symbolId == null && item.amount.isEmpty && item.costPrice.isEmpty;

  bool _hasMultipleEntries() => _fundEntries.length + _metalEntries.length > 1;

  List<_FundEntry> _getActiveFundEntries() => _fundEntries.where((e) => !_isFundEntryEmpty(e)).toList();

  List<_MetalEntry> _getActiveMetalEntries() => _metalEntries.where((e) => !_isMetalEntryEmpty(e)).toList();

  // ===== 错误标记 =====
  void _setEntryError(String key, String field, String message) {
    _entryErrors.putIfAbsent(key, () => {})[field] = message;
  }

  void _clearEntryError(String key, String field) {
    if (!(_entryErrors[key]?.containsKey(field) ?? false)) return;
    final item = _entryErrors[key]!..remove(field);
    if (item.isEmpty) _entryErrors.remove(key);
  }

  String _getEntryError(String key, String field) => _entryErrors[key]?[field] ?? '';

  bool _canSwitchInitialEntryType() {
    if (_fundEntries.length == 1 && _metalEntries.isEmpty) return _isFundEntryEmpty(_fundEntries.first);
    if (_metalEntries.length == 1 && _fundEntries.isEmpty) return _isMetalEntryEmpty(_metalEntries.first);
    return false;
  }

  bool _ensureEntriesCompleted() {
    final hasIncompleteFund = _fundEntries.any((e) => !e.collapsed && !_isFundEntryComplete(e));
    final hasIncompleteMetal = _metalEntries.any((e) => !e.collapsed && !_isMetalEntryComplete(e));
    if (hasIncompleteFund || hasIncompleteMetal) {
      _toast('请输入完整后，再添加持仓');
      return false;
    }
    return true;
  }

  void _collapseCompletedEntries() {
    for (final e in _fundEntries) {
      e.collapsed = _isFundEntryComplete(e);
    }
    for (final e in _metalEntries) {
      e.collapsed = _isMetalEntryComplete(e);
    }
  }

  void _appendFundEntry({_FundEntry? payload}) {
    _removeMetalDropdown();
    final p = payload;
    final isEmptyPayload = p == null ||
        (p.uniqueSymbol.isEmpty && p.shortName.isEmpty && p.amount.isEmpty && p.profit.isEmpty);
    if (isEmptyPayload && _canSwitchInitialEntryType()) {
      setState(() {
        _fundEntries
          ..clear()
          ..add(_createFundEntry());
        _metalEntries.clear();
      });
      return;
    }
    if (isEmptyPayload && !_ensureEntriesCompleted()) return;
    setState(() {
      _collapseCompletedEntries();
      _fundEntries.add(_createFundEntry(payload: p));
    });
  }

  void _appendMetalEntry({_MetalEntry? payload}) {
    _removeMetalDropdown();
    final p = payload;
    final isEmptyPayload = p == null ||
        (p.uniqueSymbol.isEmpty && p.shortName.isEmpty && p.amount.isEmpty && p.costPrice.isEmpty);
    if (isEmptyPayload && _canSwitchInitialEntryType()) {
      setState(() {
        _fundEntries.clear();
        _metalEntries
          ..clear()
          ..add(_createMetalEntry());
      });
      return;
    }
    if (isEmptyPayload && !_ensureEntriesCompleted()) return;
    setState(() {
      _collapseCompletedEntries();
      _metalEntries.add(_createMetalEntry(payload: p));
    });
  }

  // ===== 字段更新 =====
  void _updateFundField(String key, String field, String value) {
    setState(() {
      _clearEntryError(key, field);
      final nextValue = field == 'profit' ? _normalizeSignedDecimalInput(value) : _normalizePositiveDecimalInput(value);
      final item = _fundEntries.firstWhere((e) => e.key == key, orElse: () => _FundEntry(key: ''));
      if (item.key.isEmpty) return;
      if (field == 'amount') item.amount = nextValue;
      if (field == 'profit') item.profit = nextValue;
    });
  }

  void _updateMetalField(String key, String field, String value) {
    setState(() {
      _clearEntryError(key, field);
      final nextValue = _normalizePositiveDecimalInput(value);
      final item = _metalEntries.firstWhere((e) => e.key == key, orElse: () => _MetalEntry(key: ''));
      if (item.key.isEmpty) return;
      if (field == 'amount') item.amount = nextValue;
      if (field == 'costPrice') item.costPrice = nextValue;
    });
  }

  // ===== 数字键盘 =====
  bool _isKeyboardTarget(String key, String field) {
    final t = _numberKeyboardTarget;
    return _numberKeyboardVisible && t?.key == key && t?.field == field;
  }

  String get _numberKeyboardValue {
    final t = _numberKeyboardTarget;
    if (t == null) return '';
    if (t.type == 'fund') {
      final item = _fundEntries.where((e) => e.key == t.key).firstOrNull;
      if (item == null) return '';
      return t.field == 'amount' ? item.amount : item.profit;
    }
    final item = _metalEntries.where((e) => e.key == t.key).firstOrNull;
    if (item == null) return '';
    return t.field == 'amount' ? item.amount : item.costPrice;
  }

  bool get _numberKeyboardAllowNegative => _numberKeyboardTarget?.field == 'profit';

  void _openNumberKeyboard(String type, String key, String field) {
    _removeMetalDropdown();
    setState(() {
      _numberKeyboardTarget = _KeyboardTarget(type, key, field);
      _numberKeyboardVisible = true;
    });
  }

  void _closeNumberKeyboard() {
    if (!_numberKeyboardVisible && _numberKeyboardTarget == null) return;
    setState(() {
      _numberKeyboardVisible = false;
      _numberKeyboardTarget = null;
    });
  }

  void _handleNumberKeyboardInput(String value) {
    final t = _numberKeyboardTarget;
    if (t == null) return;
    if (t.type == 'fund') {
      _updateFundField(t.key, t.field, value);
      return;
    }
    _updateMetalField(t.key, t.field, value);
  }

  // ===== 删除/展开/收起 =====
  void _removeEntry(String type, String key) {
    if (_numberKeyboardTarget?.key == key) _closeNumberKeyboard();
    if (type == 'fund') {
      if (_fundEntries.length == 1 && _metalEntries.isEmpty) {
        _toast('至少保留一条');
        return;
      }
      setState(() => _fundEntries.removeWhere((e) => e.key == key));
      _removeMetalDropdown();
      return;
    }
    if (_metalEntries.length == 1 && _fundEntries.isEmpty) {
      _toast('至少保留一条');
      return;
    }
    setState(() => _metalEntries.removeWhere((e) => e.key == key));
    if (_activeMetalDropdownKey == key) _removeMetalDropdown();
  }

  void _expandEntry(String type, String key) {
    setState(() {
      if (type == 'fund') {
        for (final e in _fundEntries) {
          if (e.key == key) e.collapsed = false;
        }
      } else {
        for (final e in _metalEntries) {
          if (e.key == key) e.collapsed = false;
        }
      }
    });
  }

  void _collapseEntry(String type, String key) {
    if (type == 'fund') {
      final target = _fundEntries.where((e) => e.key == key).firstOrNull;
      if (target != null && !_isFundEntryComplete(target)) {
        _toast('请输入完整后，再收起持仓');
        return;
      }
      setState(() => target?.collapsed = true);
      return;
    }
    final target = _metalEntries.where((e) => e.key == key).firstOrNull;
    if (target != null && !_isMetalEntryComplete(target)) {
      _toast('请输入完整后，再收起持仓');
      return;
    }
    setState(() => target?.collapsed = true);
  }

  // ===== 显示格式化 =====
  static String _getDisplayCode(String uniqueSymbol) => uniqueSymbol.split(':').last;

  static String _formatMetricValue(String value) {
    if (value.isEmpty) return '--';
    final num = double.tryParse(value);
    if (num == null) return '--';
    return num.toStringAsFixed(2);
  }

  static String _formatSignedMetricValue(String value) {
    if (value.isEmpty) return '--';
    final num = double.tryParse(value);
    if (num == null) return '--';
    if (num > 0) return '+${num.toStringAsFixed(2)}';
    return num.toStringAsFixed(2);
  }

  // ===== 基金选择 (跳搜索页, 等待返回结果; 对应 uni-app 的 manualMassUploadSelect 事件) =====
  Future<void> _handlePickFund(String entryKey) async {
    _closeNumberKeyboard();
    final query = [
      'selectMode=emit',
      'entryKey=${Uri.encodeComponent(entryKey)}',
      if (_hasBookId) 'bookId=${Uri.encodeComponent(_bookId!)}',
    ].join('&');
    final result = await context.push<Map<String, dynamic>>('/fund/upload/search?$query');
    if (result == null || !mounted) return;
    _handleSearchData(result, entryKey);
  }

  void _handleSearchData(Map<String, dynamic> result, String entryKey) {
    setState(() {
      _clearEntryError(entryKey, 'uniqueSymbol');
      final item = _fundEntries.where((e) => e.key == entryKey).firstOrNull;
      if (item == null) return;
      final latest = result['latestPrice'];
      item.latestPrice = latest is num ? latest.toDouble() : double.tryParse('$latest');
      item.shortName = (result['shortName'] ?? result['displayName'] ?? result['name'] ?? '').toString();
      item.uniqueSymbol = (result['uniqueSymbol'] ?? result['symbolId'] ?? '').toString();
      item.symbolId = result['symbolId'] is num ? (result['symbolId'] as num).toInt() : int.tryParse('${result['symbolId'] ?? ''}');
    });
  }

  // ===== 贵金属下拉 =====
  void _toggleMetalDropdown(String entryKey) {
    _closeNumberKeyboard();
    if (_activeMetalDropdownKey == entryKey) {
      _removeMetalDropdown();
      return;
    }
    _showMetalDropdown(entryKey);
  }

  void _showMetalDropdown(String entryKey) {
    _removeMetalDropdown();
    final entry = _metalEntries.where((e) => e.key == entryKey).firstOrNull;
    if (entry == null) return;
    final width = entry.link.leaderSize?.width ?? 200;
    _activeMetalDropdownKey = entryKey;
    _metalDropdownOverlay = OverlayEntry(
      builder: (overlayContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF282828) : Colors.white;
        final borderColor = isDark ? const Color(0xFF343740) : const Color(0xFFECECF2);
        final dividerColor = isDark ? const Color(0xFF343740) : const Color(0xFFF1F2F6);
        final textColor = isDark ? AppColors.darkText : const Color(0xFF333333);
        return CompositedTransformFollower(
          link: entry.link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 41 + 5), // 82rpx 输入框 + 10rpx 间距
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: borderColor, width: 0.5),
                borderRadius: BorderRadius.circular(7), // 14rpx
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x38000000) : const Color(0x141B224F), // rgba(27,34,79,0.08)
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _metalOptions.length; i++) ...[
                    if (i > 0) Container(height: 0.5, color: dividerColor),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectMetalOption(entryKey, _metalOptions[i]),
                      child: Container(
                        height: 38, // 76rpx
                        padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _metalOptions[i].shortName,
                          style: AppTextStyles.cn(13, color: textColor, height: 1.2), // 26rpx
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_metalDropdownOverlay!);
  }

  void _removeMetalDropdown() {
    _metalDropdownOverlay?.remove();
    _metalDropdownOverlay = null;
    if (_activeMetalDropdownKey.isNotEmpty) {
      _activeMetalDropdownKey = '';
    }
  }

  void _selectMetalOption(String entryKey, _MetalOption option) {
    setState(() {
      _clearEntryError(entryKey, 'uniqueSymbol');
      final item = _metalEntries.where((e) => e.key == entryKey).firstOrNull;
      if (item != null) {
        item.shortName = option.shortName;
        item.uniqueSymbol = '${option.symbolId}';
        item.symbolId = option.symbolId;
      }
    });
    _removeMetalDropdown();
  }

  // ===== 校验 & 保存 =====
  bool _validateEntries() {
    _entryErrors.clear();
    if (!_hasBookId) {
      _toast('请选择账本');
      return false;
    }
    final activeFund = _getActiveFundEntries();
    final activeMetal = _getActiveMetalEntries();
    if (activeFund.isEmpty && activeMetal.isEmpty) {
      _toast('请添加持仓');
      return false;
    }
    var firstErrorMessage = '';
    void markError(String key, String field, String message) {
      if (firstErrorMessage.isEmpty) firstErrorMessage = message;
      _setEntryError(key, field, message);
    }

    for (final item in activeFund) {
      if (item.uniqueSymbol.isEmpty) markError(item.key, 'uniqueSymbol', '请选择你持有的基金');
      if (item.amount.isEmpty || double.tryParse(item.amount) == null) markError(item.key, 'amount', '请输入持有金额');
      if (item.profit.isEmpty || double.tryParse(item.profit) == null) markError(item.key, 'profit', '请输入持有收益');
    }
    for (final item in activeMetal) {
      if (item.uniqueSymbol.isEmpty) markError(item.key, 'uniqueSymbol', '请选择贵金属');
      if (item.amount.isEmpty || double.tryParse(item.amount) == null) markError(item.key, 'amount', '请输入贵金属持有金额');
      if (item.costPrice.isEmpty || double.tryParse(item.costPrice) == null) markError(item.key, 'costPrice', '请输入贵金属持有成本');
    }
    if (firstErrorMessage.isNotEmpty) {
      setState(() {}); // 刷新错误展示
      _toast(firstErrorMessage);
      return false;
    }
    return true;
  }

  Future<void> _handleSave() async {
    _closeNumberKeyboard();
    _removeMetalDropdown();
    if (!_validateEntries() || _saving) return;
    setState(() => _saving = true);
    try {
      // 批量保存基金
      final activeFund = _getActiveFundEntries();
      final activeMetal = _getActiveMetalEntries();
      final fundItems = activeFund
          .map((item) => {
                'bookId': int.parse(_bookId!),
                'symbolId': item.symbolId,
                'holdAmount': double.tryParse(item.amount) ?? 0,
                'holdProfit': double.tryParse(item.profit) ?? 0,
              })
          .toList();
      if (fundItems.isNotEmpty) {
        await _api.post(ApiEndpoints.assetBatchInput, data: {'items': fundItems});
      }
      // 贵金属: 逐条调用 buyAsset (quantity 传 costPrice —— 与 uni-app 源码保持一致)
      final now = DateTime.now().toIso8601String();
      for (final item in activeMetal) {
        final totalAmount = double.tryParse(item.amount) ?? 0;
        final costPrice = double.tryParse(item.costPrice) ?? 1;
        await _api.post(ApiEndpoints.assetBuy, data: {
          'bookId': int.parse(_bookId!),
          'symbolId': item.symbolId,
          'quantity': costPrice,
          'totalAmount': totalAmount,
          'serviceFee': 0,
          'transactionTime': now,
        });
      }
      if (!mounted) return;
      _toast('保存成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      // uni.navigateBack({delta: 2})
      final router = GoRouter.of(context);
      if (router.canPop()) router.pop();
      if (router.canPop()) router.pop();
    } catch (e) {
      debugPrint('批量保存失败: $e');
      if (mounted) _toast('保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppColors.darkBg : const Color(0xFFF5F5F5);
    final navbarBg = isDark ? AppColors.darkSurface : Colors.white;
    final navbarTitleColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: CustomNavBar(title: '手动输入', backgroundColor: navbarBg, titleColor: navbarTitleColor),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _closeNumberKeyboard();
          _removeMetalDropdown();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.only(
                  left: 9, right: 9, // 18rpx
                  top: 9,
                  bottom: _numberKeyboardVisible ? 360 : 130, // 720rpx / 260rpx
                ),
                children: [
                  for (final item in _fundEntries) _buildFundCard(item, isDark),
                  for (final item in _metalEntries) _buildMetalCard(item, isDark),
                  _buildAddActions(isDark),
                ],
              ),
            ),
            // 底部「完成」按钮区 (键盘弹出时隐藏)
            if (!_numberKeyboardVisible)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.only(left: 12, right: 12, top: 7, bottom: 12 + bottomInset), // 14rpx 24rpx
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? const [Color(0x00111315), Color(0xFF111315), Color(0xFF111315)]
                            : const [Color(0x00FAF7F7), Color(0xFFFAF7F7), Color(0xFFFAF7F7)],
                        stops: const [0.0, 0.26, 1.0],
                      ),
                    ),
                    child: GestureDetector(
                      onTap: _handleSave,
                      child: Container(
                        height: 47, // 94rpx
                        decoration: BoxDecoration(
                          color: const Color(0xFFE05665),
                          borderRadius: BorderRadius.circular(6), // 12rpx
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '完成',
                          style: AppTextStyles.cn(17, color: Colors.white, weight: FontWeight.w500), // 34rpx
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 数字键盘
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: MaddNumberKeyboard(
                visible: _numberKeyboardVisible,
                value: _numberKeyboardValue,
                allowNegative: _numberKeyboardAllowNegative,
                onChanged: _handleNumberKeyboardInput,
                onConfirm: _closeNumberKeyboard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 3), // 6rpx 8rpx 0
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildAddBtn('添加贵金属', () => _appendMetalEntry(), isDark),
          const SizedBox(width: 9), // 18rpx
          _buildAddBtn('添加基金', () => _appendFundEntry(), isDark),
        ],
      ),
    );
  }

  Widget _buildAddBtn(String text, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32, // 64rpx
        padding: const EdgeInsets.symmetric(horizontal: 14), // 28rpx
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282828) : const Color(0xFFFEFEFE),
          border: Border.all(color: const Color(0xFFE05665), width: 1), // 2rpx
          borderRadius: BorderRadius.circular(8), // 16rpx
        ),
        alignment: Alignment.center,
        child: Text(text, style: AppTextStyles.cn(14.5, color: const Color(0xFFE05665))), // 29rpx
      ),
    );
  }

  // ===== 基金卡片 =====
  Widget _buildFundCard(_FundEntry item, bool isDark) {
    final mutedIconColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFB9BCC8);
    return Container(
      margin: const EdgeInsets.only(bottom: 11), // 22rpx
      padding: item.collapsed
          ? const EdgeInsets.symmetric(horizontal: 11, vertical: 12) // 24rpx 22rpx
          : const EdgeInsets.all(12), // 24rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F0F3), width: 0.5),
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x081B224F), blurRadius: 6, offset: Offset(0, 2))], // rgba(27,34,79,0.03)
      ),
      child: item.collapsed
          ? _buildCollapsedSummary(
              isDark: isDark,
              title: item.shortName.isNotEmpty ? item.shortName : '基金',
              code: item.uniqueSymbol.isNotEmpty ? _getDisplayCode(item.uniqueSymbol) : '--',
              metric1Label: '持有金额',
              metric1Value: _formatMetricValue(item.amount),
              metric2Label: '持有收益',
              metric2Value: _formatSignedMetricValue(item.profit),
              metric2Color: _profitColor(item.profit),
              mutedIconColor: mutedIconColor,
              onTap: () => _expandEntry('fund', item.key),
            )
          : Column(
              children: [
                _buildFieldRow(
                  label: '持有基金',
                  isDark: isDark,
                  child: _buildFieldBox(
                    isDark: isDark,
                    active: false,
                    onTap: () => _handlePickFund(item.key),
                    child: Text(
                      item.shortName.isNotEmpty
                          ? item.shortName
                          : (_getEntryError(item.key, 'uniqueSymbol').isNotEmpty
                              ? _getEntryError(item.key, 'uniqueSymbol')
                              : '请选择基金'),
                      style: _fieldTextStyle(
                        isDark: isDark,
                        isPlaceholder: item.shortName.isEmpty,
                        isError: item.shortName.isEmpty && _getEntryError(item.key, 'uniqueSymbol').isNotEmpty,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                _buildFieldRow(
                  label: '持有金额',
                  isDark: isDark,
                  child: _buildFieldBox(
                    isDark: isDark,
                    active: _isKeyboardTarget(item.key, 'amount'),
                    onTap: () => _openNumberKeyboard('fund', item.key, 'amount'),
                    child: Text(
                      item.amount.isNotEmpty
                          ? item.amount
                          : (_getEntryError(item.key, 'amount').isNotEmpty ? _getEntryError(item.key, 'amount') : '请输入持有金额'),
                      style: _fieldTextStyle(
                        isDark: isDark,
                        isPlaceholder: item.amount.isEmpty,
                        isError: item.amount.isEmpty && _getEntryError(item.key, 'amount').isNotEmpty,
                        isInput: true,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                _buildFieldRow(
                  label: '持有收益',
                  isDark: isDark,
                  child: _buildFieldBox(
                    isDark: isDark,
                    active: _isKeyboardTarget(item.key, 'profit'),
                    onTap: () => _openNumberKeyboard('fund', item.key, 'profit'),
                    child: Text(
                      item.profit.isNotEmpty
                          ? item.profit
                          : (_getEntryError(item.key, 'profit').isNotEmpty ? _getEntryError(item.key, 'profit') : '请输入持有收益'),
                      style: _fieldTextStyle(
                        isDark: isDark,
                        isPlaceholder: item.profit.isEmpty,
                        isError: item.profit.isEmpty && _getEntryError(item.key, 'profit').isNotEmpty,
                        isInput: true,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                _buildEntryFooter(
                  tag: '基金',
                  isDark: isDark,
                  showCollapse: _isFundEntryComplete(item) && _hasMultipleEntries(),
                  collapseWithText: true,
                  onCollapse: () => _collapseEntry('fund', item.key),
                  onDelete: () => _removeEntry('fund', item.key),
                  mutedIconColor: mutedIconColor,
                ),
              ],
            ),
    );
  }

  // ===== 贵金属卡片 =====
  Widget _buildMetalCard(_MetalEntry item, bool isDark) {
    final mutedIconColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFB9BCC8);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: item.collapsed ? const EdgeInsets.symmetric(horizontal: 11, vertical: 12) : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F0F3), width: 0.5),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x081B224F), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: item.collapsed
          ? _buildCollapsedSummary(
              isDark: isDark,
              title: item.shortName.isNotEmpty ? item.shortName : '贵金属',
              code: item.uniqueSymbol.isNotEmpty ? _getDisplayCode(item.uniqueSymbol) : '--',
              metric1Label: '持有金额',
              metric1Value: _formatMetricValue(item.amount),
              metric2Label: '成本/克',
              metric2Value: _formatMetricValue(item.costPrice),
              metric2Color: null,
              mutedIconColor: mutedIconColor,
              onTap: () => _expandEntry('metal', item.key),
            )
          : Column(
              children: [
                _buildFieldRow(
                  label: '贵金属',
                  isDark: isDark,
                  child: CompositedTransformTarget(
                    link: item.link,
                    child: _buildFieldBox(
                      isDark: isDark,
                      active: false,
                      onTap: () => _toggleMetalDropdown(item.key),
                      paddingRight: 9, // 18rpx
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.shortName.isNotEmpty
                                  ? item.shortName
                                  : (_getEntryError(item.key, 'uniqueSymbol').isNotEmpty
                                      ? _getEntryError(item.key, 'uniqueSymbol')
                                      : '请选择贵金属'),
                              style: _fieldTextStyle(
                                isDark: isDark,
                                isPlaceholder: item.shortName.isEmpty,
                                isError: item.shortName.isEmpty && _getEntryError(item.key, 'uniqueSymbol').isNotEmpty,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6), // 12rpx
                          Icon(Icons.keyboard_arrow_down, size: 16, color: mutedIconColor),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFieldRow(
                  label: '持有金额',
                  isDark: isDark,
                  child: _buildFieldBox(
                    isDark: isDark,
                    active: _isKeyboardTarget(item.key, 'amount'),
                    onTap: () => _openNumberKeyboard('metal', item.key, 'amount'),
                    child: Text(
                      item.amount.isNotEmpty
                          ? item.amount
                          : (_getEntryError(item.key, 'amount').isNotEmpty ? _getEntryError(item.key, 'amount') : '请输入持有金额'),
                      style: _fieldTextStyle(
                        isDark: isDark,
                        isPlaceholder: item.amount.isEmpty,
                        isError: item.amount.isEmpty && _getEntryError(item.key, 'amount').isNotEmpty,
                        isInput: true,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                _buildFieldRow(
                  label: '成本/克',
                  isDark: isDark,
                  child: _buildFieldBox(
                    isDark: isDark,
                    active: _isKeyboardTarget(item.key, 'costPrice'),
                    onTap: () => _openNumberKeyboard('metal', item.key, 'costPrice'),
                    child: Text(
                      item.costPrice.isNotEmpty
                          ? item.costPrice
                          : (_getEntryError(item.key, 'costPrice').isNotEmpty ? _getEntryError(item.key, 'costPrice') : '请输入持有成本'),
                      style: _fieldTextStyle(
                        isDark: isDark,
                        isPlaceholder: item.costPrice.isEmpty,
                        isError: item.costPrice.isEmpty && _getEntryError(item.key, 'costPrice').isNotEmpty,
                        isInput: true,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                _buildEntryFooter(
                  tag: '贵金属',
                  isDark: isDark,
                  showCollapse: _isMetalEntryComplete(item) && _hasMultipleEntries(),
                  collapseWithText: false,
                  onCollapse: () => _collapseEntry('metal', item.key),
                  onDelete: () => _removeEntry('metal', item.key),
                  mutedIconColor: mutedIconColor,
                ),
              ],
            ),
    );
  }

  Color? _profitColor(String value) {
    if (value.isEmpty) return null;
    final num = double.tryParse(value);
    if (num == null) return null;
    if (num > 0) return AppColors.upColor; // #E05665
    if (num < 0) return AppColors.downColor; // #31B87A
    return null;
  }

  Widget _buildCollapsedSummary({
    required bool isDark,
    required String title,
    required String code,
    required String metric1Label,
    required String metric1Value,
    required String metric2Label,
    required String metric2Value,
    required Color? metric2Color,
    required Color mutedIconColor,
    required VoidCallback onTap,
  }) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF2F3137);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF9297A5);
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8F94A3);
    final valueColor = isDark ? AppColors.darkText : const Color(0xFF333333);

    Widget metric(String label, String value, Color? color) => Container(
          constraints: const BoxConstraints(minWidth: 66), // 132rpx
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTextStyles.cn(11, color: labelColor, height: 1.2)), // 22rpx
              const SizedBox(height: 6), // 12rpx
              Text(value, style: AppTextStyles.num(15, color: color ?? valueColor, weight: FontWeight.w600, height: 1.2)), // 30rpx
            ],
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 94, // 188rpx
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppTextStyles.cn(14, color: titleColor, weight: FontWeight.w600, height: 1.2), // 28rpx
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 5), // 10rpx
                Text(code, style: AppTextStyles.cn(11, color: subtitleColor, height: 1.2)), // 22rpx
              ],
            ),
          ),
          Expanded(child: const SizedBox.shrink()),
          metric(metric1Label, metric1Value, null),
          metric(metric2Label, metric2Value, metric2Color),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down, size: 18, color: mutedIconColor),
        ],
      ),
    );
  }

  Widget _buildFieldRow({required String label, required bool isDark, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9), // 18rpx
      child: Row(
        children: [
          SizedBox(
            width: 79, // 158rpx
            child: Text(
              label,
              style: AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4A3A36), height: 1.4), // 28rpx
            ),
          ),
          const SizedBox(width: 9), // 18rpx
          Expanded(child: child),
        ],
      ),
    );
  }

  TextStyle _fieldTextStyle({required bool isDark, required bool isPlaceholder, bool isError = false, bool isInput = false}) {
    if (isPlaceholder) {
      return AppTextStyles.cn(14.5, color: isError ? const Color(0xFFE05665) : (isDark ? AppColors.darkTextSecondary : const Color(0xFFB5B6BF)), height: 1.4); // 29rpx
    }
    return AppTextStyles.cn(isInput ? 13 : 14.5, color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.4);
  }

  Widget _buildFieldBox({
    required bool isDark,
    required bool active,
    required VoidCallback onTap,
    required Widget child,
    double paddingRight = 12, // 24rpx
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 点击输入框不冒泡到页面(避免关闭键盘), 由各自 onTap 处理
        onTap();
      },
      child: Container(
        height: 41, // 82rpx
        padding: EdgeInsets.only(left: 12, right: paddingRight),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF15171A) : Colors.white)
              : (isDark ? const Color(0xFF282828) : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(7), // 14rpx
          border: Border.all(color: active ? const Color(0xFF4167F1) : Colors.transparent, width: 1), // 2rpx
        ),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildEntryFooter({
    required String tag,
    required bool isDark,
    required bool showCollapse,
    required bool collapseWithText,
    required VoidCallback onCollapse,
    required VoidCallback onDelete,
    required Color mutedIconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 2), // 4rpx 8rpx 0
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tag, style: AppTextStyles.cn(13, color: const Color(0xFFE05665), weight: FontWeight.w500, height: 1.2)), // 26rpx
          const Spacer(),
          if (showCollapse)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCollapse,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Icon(Icons.keyboard_arrow_up, size: 18, color: mutedIconColor),
                    if (collapseWithText)
                      Text('收起', style: AppTextStyles.cn(11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9297A5))),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              constraints: const BoxConstraints(minWidth: 43), // 86rpx
              height: 28, // 56rpx
              padding: const EdgeInsets.symmetric(horizontal: 11), // 22rpx
              decoration: BoxDecoration(
                color: const Color(0xFFE05665),
                borderRadius: BorderRadius.circular(7), // 14rpx
              ),
              alignment: Alignment.center,
              child: Text('删除', style: AppTextStyles.cn(14, color: Colors.white)), // 28rpx
            ),
          ),
        ],
      ),
    );
  }
}
