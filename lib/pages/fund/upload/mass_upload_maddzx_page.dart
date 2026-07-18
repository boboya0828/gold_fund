import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'madd_number_keyboard.dart';

/// 添加/修改持有(单只基金) — 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/mass-upload-maddzx.vue)
/// 基金名称由上一页带入(不可改), 数字键盘输入持有金额/收益, 提交 batchinput
class MassUploadMaddzxPage extends StatefulWidget {
  final String? mode; // 'edit' → 修改持有
  final String? shortName;
  final String? symbolId;
  final String? bookId;
  final String? marketValue;
  final String? holdProfit;

  const MassUploadMaddzxPage({
    super.key,
    this.mode,
    this.shortName,
    this.symbolId,
    this.bookId,
    this.marketValue,
    this.holdProfit,
  });

  @override
  State<MassUploadMaddzxPage> createState() => _MassUploadMaddzxPageState();
}

class _MassUploadMaddzxPageState extends State<MassUploadMaddzxPage> {
  final ApiClient _api = ApiClient();

  late String _title;
  late String _shortName;
  late String _symbolId;
  late String _bookId;
  late String _amount;
  late String _profit;
  bool _saving = false;
  bool _numberKeyboardVisible = false;
  String _activeKeyboardField = ''; // 'amount' | 'profit'

  @override
  void initState() {
    super.initState();
    // onLoad
    _title = widget.mode == 'edit' ? '修改持有' : '添加持有';
    _shortName = widget.shortName ?? '';
    _symbolId = widget.symbolId ?? '';
    _bookId = widget.bookId ?? '';
    _amount = _formatTwoDecimal(widget.marketValue);
    _profit = _formatTwoDecimal(widget.holdProfit);
  }

  // ===== 工具 =====
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  static String _formatTwoDecimal(String? value) {
    final num = double.tryParse(value ?? '');
    return num != null && num.isFinite ? num.toStringAsFixed(2) : '';
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

  // ===== 数字键盘 =====
  String get _numberKeyboardValue => _activeKeyboardField == 'profit' ? _profit : _amount;

  void _openNumberKeyboard(String field) {
    setState(() {
      _activeKeyboardField = field;
      _numberKeyboardVisible = true;
    });
  }

  void _closeNumberKeyboard() {
    if (!_numberKeyboardVisible && _activeKeyboardField.isEmpty) return;
    setState(() {
      _numberKeyboardVisible = false;
      _activeKeyboardField = '';
    });
  }

  void _handleNumberKeyboardInput(String value) {
    setState(() {
      if (_activeKeyboardField == 'profit') {
        _profit = _normalizeSignedDecimalInput(value);
        return;
      }
      _amount = _normalizePositiveDecimalInput(value);
    });
  }

  // ===== 保存 =====
  Future<void> _handleSave() async {
    _closeNumberKeyboard();
    final assetAmount = double.tryParse(_formatTwoDecimal(_amount));
    final profitAmount = double.tryParse(_formatTwoDecimal(_profit));

    if (_bookId.isEmpty) {
      _toast('请选择账户');
      return;
    }
    if (_symbolId.isEmpty) {
      _toast('基金参数缺失');
      return;
    }
    if (_amount.isEmpty || assetAmount == null) {
      _toast('请输入持有金额');
      return;
    }
    if (_profit.isEmpty || profitAmount == null) {
      _toast('请输入持有收益');
      return;
    }
    if (_saving) return;

    setState(() {
      _amount = assetAmount.toStringAsFixed(2);
      _profit = profitAmount.toStringAsFixed(2);
      _saving = true;
    });
    try {
      // V2 批量导入持仓接口
      await _api.post(ApiEndpoints.assetBatchInput, data: {
        'items': [
          {
            'bookId': int.parse(_bookId),
            'symbolId': int.parse(_symbolId),
            'holdAmount': assetAmount,
            'holdProfit': profitAmount,
          }
        ],
      });
      if (!mounted) return;
      _toast('保存成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      // uni.navigateBack({delta: 2})
      final router = GoRouter.of(context);
      if (router.canPop()) router.pop();
      if (router.canPop()) router.pop();
    } catch (e) {
      debugPrint('创建资产明细失败: $e');
      if (mounted) _toast('保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppColors.darkBg : AppColors.lightBg; // #faf7f7 / #111315
    final navbarBg = isDark ? AppColors.darkSurface : AppColors.lightBg;
    final navbarTitleColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: CustomNavBar(title: _title, backgroundColor: navbarBg, titleColor: navbarTitleColor),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeNumberKeyboard,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 12, right: 12, // 24rpx
                  bottom: _numberKeyboardVisible ? 360 : 75, // 720rpx / 150rpx
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormSection(
                      label: '持有基金',
                      isDark: isDark,
                      child: _buildFieldBox(
                        isDark: isDark,
                        active: false,
                        disabled: true,
                        child: Text(
                          _shortName.isNotEmpty ? _shortName : '未选择基金',
                          style: _shortName.isNotEmpty
                              ? AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.4) // 28rpx
                              : AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB4B6BC), height: 1.4),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    _buildFormSection(
                      label: '持有金额',
                      isDark: isDark,
                      child: _buildFieldBox(
                        isDark: isDark,
                        active: _activeKeyboardField == 'amount',
                        onTap: () => _openNumberKeyboard('amount'),
                        child: Text(
                          _amount.isNotEmpty ? _amount : '输入您持有的金额',
                          style: _amount.isNotEmpty
                              ? AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.4)
                              : AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB4B6BC), height: 1.4),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    _buildFormSection(
                      label: '持有收益',
                      isDark: isDark,
                      child: _buildFieldBox(
                        isDark: isDark,
                        active: _activeKeyboardField == 'profit',
                        onTap: () => _openNumberKeyboard('profit'),
                        child: Text(
                          _profit.isNotEmpty ? _profit : '输入您持有基金的收益',
                          style: _profit.isNotEmpty
                              ? AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.4)
                              : AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB4B6BC), height: 1.4),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部「完成」按钮区 (键盘弹出时隐藏)
            if (!_numberKeyboardVisible)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset), // 24rpx + safe
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? const [Color(0x00111315), Color(0xFF111315), Color(0xFF111315)]
                            : const [Color(0x00FAF7F7), Color(0xFFFAF7F7), Color(0xFFFAF7F7)],
                        stops: const [0.0, 0.24, 1.0],
                      ),
                    ),
                    child: GestureDetector(
                      onTap: _handleSave,
                      child: Container(
                        height: 47, // 94rpx
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFFE05665) : AppColors.primary, // #E15665 / #E05665
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
                allowNegative: _activeKeyboardField == 'profit',
                onChanged: _handleNumberKeyboardInput,
                onConfirm: _closeNumberKeyboard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({required String label, required bool isDark, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 13), // 26rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8), // 16rpx
            child: Text(
              label,
              style: AppTextStyles.cn(16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF242424), height: 1.4), // 32rpx
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldBox({
    required bool isDark,
    required bool active,
    bool disabled = false,
    VoidCallback? onTap,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44, // 88rpx
        padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF15171A) : Colors.white)
              : (isDark ? const Color(0xFF282828) : Colors.white),
          borderRadius: BorderRadius.circular(7), // 14rpx
          border: Border.all(
            color: active ? const Color(0xFF4167F1) : (isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F2F4)),
            width: 1, // 2rpx
          ),
        ),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
