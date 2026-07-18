import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 修改贵金属持有页 — uni-app 对应: pages/index/fund/gjs-holding-edit.vue
/// 入口 query 参数: assetId / bookId / symbolId / uniqueSymbol / shortName /
/// holdQuantity / holdCostAmount / comment。
class GjsHoldingEditPage extends StatefulWidget {
  final String assetId;
  final String bookId;
  final String symbolId;
  final String uniqueSymbol;
  final String shortName;
  final String holdQuantity;
  final String holdCostAmount;
  final String comment;

  const GjsHoldingEditPage({
    super.key,
    this.assetId = '',
    this.bookId = '',
    this.symbolId = '',
    this.uniqueSymbol = '',
    this.shortName = '',
    this.holdQuantity = '',
    this.holdCostAmount = '',
    this.comment = '',
  });

  @override
  State<GjsHoldingEditPage> createState() => _GjsHoldingEditPageState();
}

class _GjsHoldingEditPageState extends State<GjsHoldingEditPage> {
  final ApiClient _api = ApiClient();

  late final String _assetId = widget.assetId;
  late String _bookId = widget.bookId;
  late String _symbolId = widget.symbolId;
  late String _uniqueSymbol = widget.uniqueSymbol;
  late String _shortName = widget.shortName;

  late final TextEditingController _holdQuantityCtl;
  late final TextEditingController _holdCostAmountCtl;
  late final TextEditingController _commentCtl;

  bool _saving = false;

  // ===== 生命周期 =====

  @override
  void initState() {
    super.initState();
    // 源码 onLoad: 由路由参数初始化表单
    _holdQuantityCtl = TextEditingController(text: _trimNumberText(widget.holdQuantity));
    _holdCostAmountCtl = TextEditingController(text: _formatAmount(widget.holdCostAmount));
    _commentCtl = TextEditingController(text: widget.comment);
    _loadAssetDetail();
  }

  @override
  void dispose() {
    _holdQuantityCtl.dispose();
    _holdCostAmountCtl.dispose();
    _commentCtl.dispose();
    super.dispose();
  }

  // ===== 工具函数（源码 formatAmount / trimNumberText） =====

  /// 源码 formatAmount: 两位小数，非法输入返回空串
  String _formatAmount(dynamic value, [int digits = 2]) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null || !n.isFinite) return '';
    return n.toStringAsFixed(digits);
  }

  /// 源码 trimNumberText: 4 位小数后去尾零，非法输入返回空串
  String _trimNumberText(dynamic value, [int digits = 4]) {
    if (value == null || value.toString().isEmpty) return '';
    final n = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (n == null || !n.isFinite) return '';
    var fixed = n.toStringAsFixed(digits);
    if (fixed.contains('.')) {
      fixed = fixed.replaceAll(RegExp(r'0+$'), '');
      if (fixed.endsWith('.')) fixed = fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return e.message ?? '修改失败';
    }
    return e.toString();
  }

  // ===== 数据加载（源码 loadAssetDetail / applyAssetDetail） =====

  void _applyAssetDetail(Map<String, dynamic> detail) {
    _bookId = '${detail['bookId'] ?? _bookId}';
    _symbolId = '${detail['symbolId'] ?? _symbolId}';
    _uniqueSymbol = '${detail['uniqueSymbol'] ?? _uniqueSymbol}';
    final name = '${detail['shortName'] ?? detail['name'] ?? ''}';
    if (name.isNotEmpty) _shortName = name;
    final quantity = _trimNumberText(detail['holdQuantity'] ?? detail['quantity']);
    if (quantity.isNotEmpty) _holdQuantityCtl.text = quantity;
    final amount = _formatAmount(detail['holdCostAmount'] ?? detail['costAmount']);
    if (amount.isNotEmpty) _holdCostAmountCtl.text = amount;
    if (detail['comment'] != null) _commentCtl.text = '${detail['comment']}';
  }

  Future<void> _loadAssetDetail() async {
    if (_assetId.isEmpty) return;
    try {
      final targetBookId = _bookId.isNotEmpty ? int.tryParse(_bookId) : null;
      final res = await _api.get(
        ApiEndpoints.assetListV2,
        queryParameters: targetBookId != null ? {'bookId': targetBookId} : null,
      );
      final body = res.data;
      final data = body is Map && body.containsKey('data') ? body['data'] : body;
      final List list;
      if (data is Map && data['list'] is List) {
        list = data['list'] as List;
      } else if (data is List) {
        list = data;
      } else {
        list = const [];
      }
      for (final raw in list) {
        if (raw is! Map) continue;
        if ('${raw['assetId']}' == _assetId) {
          if (mounted) {
            setState(() => _applyAssetDetail(raw.cast<String, dynamic>()));
          }
          return;
        }
      }
    } catch (_) {
      // 源码: console.error('获取贵金属持仓详情失败')
    }
  }

  // ===== 保存（源码 validateForm / handleSave） =====

  bool _validateForm() {
    if (_assetId.isEmpty) {
      _toast('当前贵金属缺少资产ID');
      return false;
    }
    final quantity = double.tryParse(_holdQuantityCtl.text);
    if (quantity == null || quantity == 0) {
      _toast('请输入持有重量');
      return false;
    }
    final amount = double.tryParse(_holdCostAmountCtl.text);
    if (amount == null || amount == 0) {
      _toast('请输入持有成本');
      return false;
    }
    return true;
  }

  Future<void> _handleSave() async {
    if (_saving || !_validateForm()) return;
    if (_bookId.isEmpty || _symbolId.isEmpty) {
      _toast('当前贵金属缺少账本或标的信息');
      return;
    }
    setState(() => _saving = true);
    try {
      final quantity =
          double.parse(double.parse(_holdQuantityCtl.text).toStringAsFixed(4));
      await _api.post(ApiEndpoints.assetBatchInput, data: {
        'items': [
          {
            'bookId': int.parse(_bookId),
            'symbolId': int.parse(_symbolId),
            'holdAmount': quantity,
            'holdProfit': 0,
          },
        ],
      });
      if (!mounted) return;
      _toast('修改成功');
      // 源码: 400ms 后返回上一页
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    } catch (e) {
      if (mounted) _toast(_errMsg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
      appBar: CustomNavBar(
        title: '修改贵金属持有',
        backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 75), // 0 24rpx 150rpx
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMetalSection(isDark),
                  _buildInputSection(
                    isDark,
                    label: '持有重量',
                    controller: _holdQuantityCtl,
                    placeholder: '输入您持有的重量',
                    unit: '克',
                  ),
                  _buildInputSection(
                    isDark,
                    label: '持有成本',
                    controller: _holdCostAmountCtl,
                    placeholder: '输入您持有贵金属的成本',
                    prefix: '￥',
                    unit: '元',
                  ),
                  _buildRemarkSection(isDark),
                ],
              ),
            ),
          ),
          _buildBottomArea(isDark),
        ],
      ),
    );
  }

  Color _fieldBg(bool isDark) => isDark ? AppColors.darkSurface : Colors.white;

  Color _fieldBorder(bool isDark) =>
      isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F2F4);

  Color _textPrimary(bool isDark) =>
      isDark ? AppColors.darkText : const Color(0xFF333333);

  Color _placeholderColor(bool isDark) =>
      isDark ? const Color(0xFF686E78) : const Color(0xFFB4B6BC);

  /// 持有贵金属（只读，field-box-disabled）
  Widget _buildMetalSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 13), // 26rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8), // 16rpx
            child: Text(
              '持有贵金属',
              style: AppTextStyles.cn(16,
                  color: isDark ? AppColors.darkText : const Color(0xFF242424),
                  height: 1.4),
            ),
          ),
          Container(
            height: 44, // 88rpx
            padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _fieldBg(isDark),
              borderRadius: BorderRadius.circular(7), // 14rpx
              border: Border.all(color: _fieldBorder(isDark), width: 0.5),
            ),
            child: Text(
              _shortName.isNotEmpty ? _shortName : '未选择贵金属',
              style: AppTextStyles.cn(14,
                  color: _shortName.isNotEmpty
                      ? _textPrimary(isDark)
                      : _placeholderColor(isDark),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 持有重量 / 持有成本（field-box + input）
  Widget _buildInputSection(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    required String placeholder,
    String? prefix,
    required String unit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 13), // 26rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8), // 16rpx
            child: Text(
              label,
              style: AppTextStyles.cn(16,
                  color: isDark ? AppColors.darkText : const Color(0xFF242424),
                  height: 1.4),
            ),
          ),
          Container(
            height: 44, // 88rpx
            padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
            decoration: BoxDecoration(
              color: _fieldBg(isDark),
              borderRadius: BorderRadius.circular(7), // 14rpx
              border: Border.all(color: _fieldBorder(isDark), width: 0.5),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4), // 8rpx
                    child: Text(prefix,
                        style: AppTextStyles.num(14, color: _textPrimary(isDark))),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.num(14, color: _textPrimary(isDark)),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: placeholder,
                      hintStyle:
                          AppTextStyles.num(14, color: _placeholderColor(isDark)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6), // 12rpx
                  child: Text(unit,
                      style: AppTextStyles.cn(14, color: _textPrimary(isDark))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 备注（field-box-textarea）
  Widget _buildRemarkSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 13), // 26rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8), // 16rpx
            child: Text(
              '备注',
              style: AppTextStyles.cn(16,
                  color: isDark ? AppColors.darkText : const Color(0xFF242424),
                  height: 1.4),
            ),
          ),
          Container(
            height: 90, // 180rpx
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 24rpx 20rpx
            decoration: BoxDecoration(
              color: _fieldBg(isDark),
              borderRadius: BorderRadius.circular(7), // 14rpx
              border: Border.all(color: _fieldBorder(isDark), width: 0.5),
            ),
            child: TextField(
              controller: _commentCtl,
              maxLength: 200,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTextStyles.cn(14, color: _textPrimary(isDark), height: 1.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                hintText: '可填写购买渠道、金价说明等',
                hintStyle: AppTextStyles.cn(14, color: _placeholderColor(isDark)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部固定保存按钮（bottom-area / next-btn）
  Widget _buildBottomArea(bool isDark) {
    final bg = isDark ? AppColors.darkBg : const Color(0xFFFAF7F7);
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, 12 + MediaQuery.of(context).padding.bottom), // 0 24rpx 24rpx+safe
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withValues(alpha: 0), bg, bg],
          stops: const [0, 0.24, 1],
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleSave,
        child: Container(
          height: 47, // 94rpx
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary, // #E15665
            borderRadius: BorderRadius.circular(6), // 12rpx
          ),
          child: Text(
            _saving ? '保存中...' : '完成',
            style: AppTextStyles.cn(17,
                color: Colors.white, weight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
