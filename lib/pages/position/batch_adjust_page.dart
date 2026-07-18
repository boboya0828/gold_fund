import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/text_styles.dart';
import '../fund/upload/madd_number_keyboard.dart';
import 'widgets/batch_adjust_widgets.dart';
import 'widgets/position_sort_widgets.dart';

/// 批量加减仓页 — 1:1 复刻 uni-app pages/positionv1/batch-adjust.vue
/// 持仓多选 → 统一金额弹框 → 二次确认 → 逐只编辑金额 → 批量提交
/// query: bookId (可选, 指定账本), preSelectedAssetId (可选, 进入页面预选中的持仓)
///
/// 平台差异说明：
/// - umeng 埋点 (trackBatchAdjustEvent) 不实现（平台专有能力）。
/// - 自定义数字键盘复用 lib/pages/fund/upload/madd_number_keyboard.dart
///   （同一 uni-app 组件 CustomNumberKeyboard.vue 的既有 1:1 复刻）。
/// - uni-app 数字键盘 z-index 高于弹窗；这里键盘置于页面 Stack 最上层，效果一致。
class BatchAdjustPage extends StatefulWidget {
  final int? bookId;
  final int? preSelectedAssetId;
  const BatchAdjustPage({super.key, this.bookId, this.preSelectedAssetId});

  @override
  State<BatchAdjustPage> createState() => _BatchAdjustPageState();
}

/// uni-app api.js batchTradeByAmount → POST /asset/api/Asset/trades/batch-amount
const _endpointBatchTradeByAmount = ApiEndpoints.assetTradesBatchAmount;

/// 持仓行模型 (uni-app fetchPositionList map 后的结构)
class BatchAdjustItem {
  final int id; // assetId || id || index
  final String name; // shortName || name || '--'
  final String shortName;
  final String code;
  final int? assetId;
  final int? symbolId;
  final double marketValue;
  final int? bookId;

  const BatchAdjustItem({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
    required this.assetId,
    required this.symbolId,
    required this.marketValue,
    required this.bookId,
  });
}

/// 数字键盘目标: modal=统一金额弹框 / item=逐只编辑 (uni-app numberKeyboardTarget)
typedef _KeyboardTarget = ({String type, int? id});

/// 提交校验异常 (uni-app throw new Error('xxx 缺少xxID') 的等价物)
class _SubmitException implements Exception {
  final String message;
  _SubmitException(this.message);
}

class _BatchAdjustPageState extends State<BatchAdjustPage> {
  static const _accent = Color(0xFFE05665);
  final ApiClient _api = ApiClient();

  List<BatchAdjustItem> _positionList = [];
  Set<int> _selectedIds = {};

  bool _showAmountModal = false;
  bool _showConfirmModal = false;
  String _amountMode = 'buy'; // 'buy' | 'sell'
  String _amountInput = '';
  bool _isEditingAmounts = false;
  Map<int, String> _itemAmounts = {};
  bool _submitting = false;
  bool _numberKeyboardVisible = false;
  _KeyboardTarget? _numberKeyboardTarget;

  bool get _hasBookId => widget.bookId != null;
  int get _selectedCount => _selectedIds.length;
  bool get _isAllSelected => _positionList.isNotEmpty && _selectedIds.length == _positionList.length;

  String get _amountPrefixText => _amountMode == 'sell' ? '-¥' : '¥';
  String get _amountModalTitle => _amountMode == 'buy' ? '批量加仓金额' : '批量减仓金额';
  String get _valueHeaderText {
    if (!_isEditingAmounts) return '持有金额';
    return _amountMode == 'buy' ? '加仓金额' : '减仓金额';
  }

  /// uni-app numberKeyboardValue
  String get _numberKeyboardValue {
    final target = _numberKeyboardTarget;
    if (target == null) return '';
    if (target.type == 'modal') return _amountInput;
    return _itemAmounts[target.id] ?? '';
  }

  /// uni-app confirmModalContent
  String get _confirmModalContent {
    final action = _amountMode == 'buy' ? '加仓' : '减仓';
    if (!_isEditingAmounts) {
      return '确定批量$action $_selectedCount 只基金，每只 ${_formatAdjustMoney(_amountInput)} 元吗？';
    }
    var total = 0.0;
    for (final id in _selectedIds) {
      total += _toNumber(_itemAmounts[id]);
    }
    return '确定批量$action $_selectedCount 只基金，总金额为 ${_formatAdjustMoney(total)} 元吗？';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPositionList());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  // ===== 数值/格式化工具 (1:1 uni-app) =====

  double _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }

  /// uni-app formatMoney: toFixed(2), 非数值 → '0.00'
  String _formatMoney(dynamic value, [int digits = 2]) {
    double? numValue;
    if (value is num) {
      numValue = value.toDouble();
    } else {
      numValue = double.tryParse(value?.toString() ?? '');
    }
    if (numValue == null || !numValue.isFinite) return '0.${'0' * digits}';
    return numValue.toStringAsFixed(digits);
  }

  /// uni-app formatAdjustMoney: 减仓加负号
  String _formatAdjustMoney(dynamic value, [int digits = 2]) =>
      '${_amountMode == 'sell' ? '-' : ''}${_formatMoney(value, digits)}';

  /// uni-app normalizeAmountInput: 去非法字符 + 只保留第一个小数点
  String _normalizeAmountInput(dynamic value) {
    final numeric = (value?.toString() ?? '').replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  // ===== 数字键盘 (uni-app openNumberKeyboard / closeNumberKeyboard / handleNumberKeyboardInput) =====

  void _openNumberKeyboard(String type, [int? id]) {
    setState(() {
      _numberKeyboardTarget = (type: type, id: id);
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
    final nextValue = _normalizeAmountInput(value);
    final target = _numberKeyboardTarget;
    if (target == null) return;
    setState(() {
      if (target.type == 'modal') {
        _amountInput = nextValue;
      } else {
        _itemAmounts = Map.of(_itemAmounts)..[target.id!] = nextValue;
      }
    });
  }

  // ===== 数据加载 (uni-app fetchPositionList → getAssetList(bookId?)) =====

  Future<void> _fetchPositionList() async {
    try {
      final res = await _api.get(
        ApiEndpoints.assetListV2,
        queryParameters: _hasBookId ? {'bookId': widget.bookId} : null,
      );
      // uni-app: const data = res?.data || res; list = data?.list ?? data
      dynamic payload = res.data;
      if (payload is Map && payload['data'] != null) payload = payload['data'];
      final List list = payload is Map
          ? (payload['list'] is List ? payload['list'] as List : const [])
          : (payload is List ? payload : const []);
      final items = <BatchAdjustItem>[];
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e is! Map) continue;
        final rawBookId = (e['bookId'] as num?)?.toInt();
        items.add(BatchAdjustItem(
          id: (e['assetId'] as num?)?.toInt() ?? (e['id'] as num?)?.toInt() ?? i,
          name: (e['shortName'] ?? e['name'] ?? '--').toString(),
          shortName: (e['shortName'] ?? '').toString(),
          code: (e['code'] ?? e['symbolCode'] ?? '').toString(),
          assetId: (e['assetId'] as num?)?.toInt(),
          symbolId: (e['symbolId'] as num?)?.toInt(),
          marketValue: (e['marketValue'] as num?)?.toDouble() ?? 0,
          bookId: rawBookId ?? (_hasBookId ? widget.bookId : null),
        ));
      }
      if (!mounted) return;
      setState(() {
        _positionList = items;
        // uni-app: 预选中 preSelectedAssetId (存在才选中)
        final preId = widget.preSelectedAssetId;
        if (preId != null && items.any((e) => e.id == preId)) {
          _selectedIds = {preId};
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _positionList = [];
          _selectedIds = {};
        });
      }
    }
  }

  // ===== 选择 (uni-app toggleSelectItem / toggleSelectAll) =====

  void _toggleSelectItem(BatchAdjustItem item) {
    if (_isEditingAmounts) return;
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _toggleSelectAll() {
    if (_isEditingAmounts) return;
    setState(() {
      if (_isAllSelected) {
        _selectedIds = {};
      } else {
        _selectedIds = _positionList.map((e) => e.id).toSet();
      }
    });
  }

  // ===== 金额弹框 (uni-app openAmountModal / closeAmountModal / confirmAmountInput) =====

  void _openAmountModal(String mode) {
    if (_selectedCount == 0) {
      _toast('请先选择持仓');
      return;
    }
    setState(() {
      _amountMode = mode;
      _amountInput = '';
      _isEditingAmounts = false;
      _itemAmounts = {};
      _numberKeyboardVisible = false;
      _numberKeyboardTarget = null;
      _showAmountModal = true;
    });
  }

  void _closeAmountModal() {
    setState(() => _showAmountModal = false);
    _closeNumberKeyboard();
  }

  /// 弹框「完成」: 统一金额分摊到每只选中持仓 → 打开二次确认
  void _confirmAmountInput() {
    final amount = _toNumber(_amountInput);
    if (amount <= 0) {
      _toast('请输入有效的金额');
      return;
    }
    final amountStr = amount.toStringAsFixed(2);
    setState(() {
      _itemAmounts = {for (final id in _selectedIds) id: amountStr};
      _showAmountModal = false;
      _showConfirmModal = true;
    });
    _closeNumberKeyboard();
  }

  // ===== 二次确认弹框 (uni-app handleConfirmCancel) =====
  // 注: 源码另有 closeConfirmModal 绑定于 up-modal @close, 但 closeOnClickOverlay=false
  // 时该事件不会触发, 属死代码, 这里不迁移。

  /// 「再想想」→ 回到逐只编辑模式
  void _handleConfirmCancel() {
    setState(() {
      _showConfirmModal = false;
      _isEditingAmounts = true;
    });
    _closeNumberKeyboard();
  }

  // ===== 逐只编辑 (uni-app handleCancelEdit / handleEditSubmit) =====

  void _handleCancelEdit() {
    setState(() {
      _isEditingAmounts = false;
      _itemAmounts = {};
      _amountInput = '';
    });
    _closeNumberKeyboard();
  }

  void _handleEditSubmit() {
    if (_selectedCount == 0) {
      _toast('请先选择持仓');
      return;
    }
    final invalid = _selectedIds.any((id) => _toNumber(_itemAmounts[id]) <= 0);
    if (invalid) {
      _toast('请填写有效的金额');
      return;
    }
    setState(() => _showConfirmModal = true);
  }

  // ===== 提交 (uni-app submitBatch → batchTradeByAmount) =====

  Future<void> _submitBatch() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _showConfirmModal = false;
    });

    // uni.showLoading('提交中...') 期间禁止返回
    var loadingShown = false;
    void hideLoading() {
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
    }

    try {
      final selectedItems = _positionList.where((e) => _selectedIds.contains(e.id)).toList();
      final transactionType = _amountMode == 'buy' ? 1 : 2;
      final transactionTime = DateTime.now().toUtc().toIso8601String(); // new Date().toISOString()
      final items = <Map<String, dynamic>>[];
      for (final item in selectedItems) {
        final amount = _toNumber(_itemAmounts[item.id]);
        if (amount <= 0) continue;
        if (_amountMode == 'buy') {
          final bookId = item.bookId ?? widget.bookId;
          if (bookId == null) {
            throw _SubmitException('${item.shortName.isNotEmpty ? item.shortName : item.name} 缺少账本ID，无法加仓');
          }
          final symbolId = item.symbolId;
          if (symbolId == null) {
            throw _SubmitException('${item.shortName.isNotEmpty ? item.shortName : item.name} 缺少标的ID，无法加仓');
          }
          items.add({
            'clientItemId': '${item.id}',
            'transactionType': transactionType,
            'bookId': bookId,
            'symbolId': symbolId,
            'amount': amount,
            'serviceFee': 0,
            'transactionTime': transactionTime,
          });
        } else {
          final assetId = item.assetId;
          if (assetId == null) {
            throw _SubmitException('${item.shortName.isNotEmpty ? item.shortName : item.name} 缺少资产ID，无法减仓');
          }
          items.add({
            'clientItemId': '${item.id}',
            'transactionType': transactionType,
            'assetId': assetId,
            'amount': amount,
            'serviceFee': 0,
            'transactionTime': transactionTime,
          });
        }
      }

      if (items.isEmpty) {
        _toast('没有可提交的项');
        return;
      }

      loadingShown = true;
      _showLoading();
      final res = await _api.post(_endpointBatchTradeByAmount, data: {'items': items});
      hideLoading();
      // 业务码非 0/200 视为失败 (req.js 会 toast 后端 message; 对齐 position_sort_page 的处理)
      final data = res.data;
      final code = data is Map ? (data['code'] as num?)?.toInt() : null;
      if (code != null && code != 0 && code != 200) {
        throw _SubmitException(data is Map && data['message'] != null ? data['message'].toString() : '提交失败');
      }
      _toast('提交成功');
      // uni-app: setTimeout 400ms 后 navigateBack
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) context.pop();
    } catch (e) {
      hideLoading();
      final msg = e is _SubmitException
          ? e.message
          : (e is DioException && (e.message ?? '').isNotEmpty)
              ? e.message!
              : '提交失败';
      _toast(msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// uni.showLoading({ title: '提交中...' }) 等价物
  void _showLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xCC303133),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            ),
            SizedBox(height: 8),
            Text('提交中...', style: TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(children: [
        Column(children: [
          CustomNavBar(
            title: '批量加减仓',
            backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
            titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 64), // 0 24rpx 128rpx
              child: Container(
                margin: const EdgeInsets.only(top: 9), // 18rpx
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)), // 16rpx
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _buildHeader(isDark),
                  if (_positionList.isEmpty)
                    _buildEmpty(isDark)
                  else
                    for (final item in _positionList) _buildRow(item, isDark),
                ]),
              ),
            ),
          ),
        ]),
        // 底部操作栏 (fixed bottom)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: BatchAdjustBottomBar(
            isEditingAmounts: _isEditingAmounts,
            selectedCount: _selectedCount,
            isDark: isDark,
            onBatchSell: () => _openAmountModal('sell'),
            onBatchBuy: () => _openAmountModal('buy'),
            onCancelEdit: _handleCancelEdit,
            onEditSubmit: _handleEditSubmit,
          ),
        ),
        // 弹框遮罩 + 弹框 (closeOnClickOverlay=false: 点击遮罩不关闭)
        if (_showAmountModal || _showConfirmModal)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // 吞掉点击, 不穿透
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: _showAmountModal
                    ? BatchAdjustAmountModal(
                        title: _amountModalTitle,
                        amountInput: _amountInput,
                        amountPrefixText: _amountPrefixText,
                        tipText: '每只基金统一${_amountMode == 'buy' ? '加仓' : '减仓'}',
                        isDark: isDark,
                        onOpenKeyboard: () => _openNumberKeyboard('modal'),
                        onClear: () => setState(() => _amountInput = ''),
                        onCancel: _closeAmountModal,
                        onConfirm: _confirmAmountInput,
                      )
                    : BatchAdjustConfirmModal(
                        content: _confirmModalContent,
                        isDark: isDark,
                        onCancel: _handleConfirmCancel,
                        onConfirm: _submitBatch,
                      ),
              ),
            ),
          ),
        // 自定义数字键盘 (z-index 最高, 对齐 uni-app keyboard z-index 10120 > popup)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MaddNumberKeyboard(
            visible: _numberKeyboardVisible,
            value: _numberKeyboardValue,
            allowNegative: false,
            onChanged: _handleNumberKeyboardInput,
            onConfirm: _closeNumberKeyboard,
          ),
        ),
      ]),
    );
  }

  /// .settings-header: grid 62rpx 1fr 180rpx, padding 18rpx 20rpx 14rpx
  Widget _buildHeader(bool isDark) {
    final color = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
      color: isDark ? const Color(0xFF202125) : const Color(0xEBFFFFFF), // rgba(255,255,255,0.92)
      child: Row(children: [
        SizedBox(
          width: 31, // 62rpx
          child: _positionList.isNotEmpty && !_isEditingAmounts
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: PositionSortCheckBox(checked: _isAllSelected, isDark: isDark, onTap: _toggleSelectAll),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: Text('持仓名称', style: AppTextStyles.cn(12, color: color))), // 24rpx
        SizedBox(
          width: 90, // 180rpx
          child: Text(_valueHeaderText, textAlign: TextAlign.right, style: AppTextStyles.cn(12, color: color)),
        ),
      ]),
    );
  }

  /// .empty-state: 暂无数据
  Widget _buildEmpty(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12), // 80rpx 24rpx
      color: isDark ? const Color(0xFF202125) : Colors.white,
      child: Text(
        '暂无数据',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9)), // 26rpx
      ),
    );
  }

  /// .settings-row: padding 18rpx 20rpx, border-top 1rpx
  Widget _buildRow(BatchAdjustItem item, bool isDark) {
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final mutedColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(children: [
        // row-select: 62rpx (编辑态无勾选框, 占位保留)
        SizedBox(
          width: 31,
          child: !_isEditingAmounts
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: PositionSortCheckBox(
                    checked: _selectedIds.contains(item.id),
                    isDark: isDark,
                    onTap: () => _toggleSelectItem(item),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // row-name (点击同勾选)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleSelectItem(item),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.shortName.isNotEmpty ? item.shortName : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13, color: textColor), // 26rpx
              ),
              if (item.code.isNotEmpty) ...[
                const SizedBox(height: 1), // gap 2rpx
                Text(
                  item.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cn(10.5, color: mutedColor), // 21rpx
                ),
              ],
            ]),
          ),
        ),
        // row-value: 180rpx, 右对齐
        SizedBox(
          width: 90,
          child: _isEditingAmounts ? _buildAmountInput(item, isDark) : _buildValueText(item, textColor),
        ),
      ]),
    );
  }

  /// .row-value-text: formatMoney(marketValue)
  Widget _buildValueText(BatchAdjustItem item, Color textColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        _formatMoney(item.marketValue),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cn(13, color: textColor), // 26rpx
      ),
    );
  }

  /// .row-amount-input-wrap: 前缀(¥/-¥) + 只读输入框(点击打开数字键盘)
  Widget _buildAmountInput(BatchAdjustItem item, bool isDark) {
    final value = _itemAmounts[item.id] ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNumberKeyboard('item', item.id),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(
          _amountPrefixText,
          style: AppTextStyles.cn(12, color: _accent, weight: FontWeight.w500), // 24rpx
        ),
        const SizedBox(width: 2), // gap 4rpx
        Container(
          width: 60, // 120rpx
          height: 24, // 48rpx
          padding: const EdgeInsets.symmetric(horizontal: 5), // 0 10rpx
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFFAFAFA),
            border: Border.all(color: isDark ? const Color(0xFF4A4F58) : const Color(0xFFE6E6E6), width: 0.5),
            borderRadius: BorderRadius.circular(4), // 8rpx
          ),
          alignment: Alignment.centerRight,
          child: Text(
            value.isEmpty ? '0.00' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: value.isEmpty
                ? AppTextStyles.num(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999))
                : AppTextStyles.num(13, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)), // 26rpx numFamily
          ),
        ),
      ]),
    );
  }
}
