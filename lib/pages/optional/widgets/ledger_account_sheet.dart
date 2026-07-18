import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import 'ledger_book_api.dart';

/// 快捷创建账户底部弹层 — 1:1 复刻 uni-app components/create-account-sheet.vue
/// 自定义输入 + 三个快捷渠道(支付宝/天天基金/腾讯理财), 重名自动追加序号
class LedgerAccountSheet extends StatefulWidget {
  final bool isDark;
  final LedgerBookType bookType;
  final List<String> existingNames;

  const LedgerAccountSheet({
    super.key,
    required this.isDark,
    required this.bookType,
    required this.existingNames,
  });

  /// 返回 true=创建成功(需刷新列表)
  static Future<bool?> show(
    BuildContext context, {
    required bool isDark,
    required LedgerBookType bookType,
    required List<String> existingNames,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LedgerAccountSheet(isDark: isDark, bookType: bookType, existingNames: existingNames),
    );
  }

  @override
  State<LedgerAccountSheet> createState() => _LedgerAccountSheetState();
}

class _LedgerAccountSheetState extends State<LedgerAccountSheet> {
  static const _accent = Color(0xFFE05665);
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _selectedQuickName = '';
  bool _submitting = false;

  // uni-app quickOptions
  static const _quickOptions = [
    ('支付宝', 'assets/images/img/zfb.png'),
    ('天天基金', 'assets/images/img/ttjj.png'),
    ('腾讯理财', 'assets/images/img/txlc.png'),
  ];

  @override
  void initState() {
    super.initState();
    // handleNameBlur: 失焦时去重
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final next = _availableName(_ctrl.text);
        if (next != _ctrl.text) _ctrl.text = next;
        setState(() => _selectedQuickName = _quickOptions.any((e) => e.$1 == next) ? next : '');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// uni-app getAvailableBookName: 与已有账户重名时追加 1/2/3...
  String _availableName(String name) {
    final base = name.trim();
    if (base.isEmpty) return '';
    final existing = widget.existingNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (!existing.contains(base)) return base;
    var suffix = 1;
    var next = '$base$suffix';
    while (existing.contains(next)) {
      suffix += 1;
      next = '$base$suffix';
    }
    return next;
  }

  void _onNameChanged(String value) {
    setState(() => _selectedQuickName = _quickOptions.any((e) => e.$1 == value) ? value : '');
  }

  void _selectQuickName(String name) {
    _ctrl.text = _availableName(name);
    setState(() => _selectedQuickName = name);
    FocusScope.of(context).unfocus(); // uni.hideKeyboard()
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _availableName(_ctrl.text);
    if (name.isEmpty) {
      _toast('请输入账户名称');
      return;
    }
    setState(() => _submitting = true);
    try {
      await LedgerBookApi(widget.bookType).createBook(name);
      _toast('创建成功');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _toast('创建失败');
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final panelBg = isDark ? const Color(0xFF202125) : Colors.white;
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final itemBg = isDark ? const Color(0xFF282828) : const Color(0xFFF6F6F8);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // 键盘弹出时整体上移
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(17, 17, 17, 22 + bottomInset), // 34rpx / 44rpx+safe
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), // 30rpx
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header: 标题居中 + 右侧关闭
            Stack(children: [
              Center(
                child: Text('创建账户',
                    style: AppTextStyles.cn(18, color: textColor, weight: FontWeight.w700, height: 1)), // 36rpx
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _submitting ? null : () => Navigator.pop(context, false),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF4B4B4B)),
                  ),
                ),
              ),
            ]),
            // 自定义创建
            _section(
              label: '自定义创建',
              textColor: textColor,
              child: Container(
                height: 43, // 86rpx
                padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
                decoration: BoxDecoration(color: itemBg, borderRadius: BorderRadius.circular(8)), // 16rpx
                alignment: Alignment.center,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  maxLength: 8,
                  onChanged: _onNameChanged,
                  style: AppTextStyles.cn(14, color: textColor, height: 1.4), // 28rpx
                  cursorColor: _accent,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: '请输入账户名称',
                    hintStyle: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFC8C8CE)),
                  ),
                ),
              ),
            ),
            // 快捷创建
            _section(
              label: '快捷创建',
              textColor: textColor,
              child: Column(
                children: [
                  for (final opt in _quickOptions) ...[
                    const SizedBox(height: 9), // margin-top 18rpx
                    _quickItem(opt.$1, opt.$2, itemBg),
                  ],
                ],
              ),
            ),
            // 确认按钮
            GestureDetector(
              onTap: _submit,
              child: Opacity(
                opacity: _submitting ? 0.75 : 1,
                child: Container(
                  margin: const EdgeInsets.only(top: 21), // 42rpx
                  height: 44, // 88rpx
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(22), // 999rpx
                    boxShadow: [
                      BoxShadow(color: _accent.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _submitting ? '提交中...' : '确认',
                    style: AppTextStyles.cn(16, color: Colors.white, weight: FontWeight.w700), // 32rpx
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String label, required Color textColor, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20), // 40rpx
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9), // 18rpx
          child: Text(label, style: AppTextStyles.cn(14, color: textColor, weight: FontWeight.w600, height: 1)), // 28rpx
        ),
        child,
      ]),
    );
  }

  Widget _quickItem(String name, String icon, Color itemBg) {
    final isDark = widget.isDark;
    final active = _selectedQuickName == name;
    return GestureDetector(
      onTap: () => _selectQuickName(name),
      child: Container(
        height: 43, // 86rpx
        padding: const EdgeInsets.symmetric(horizontal: 14), // 28rpx
        decoration: BoxDecoration(
          color: active ? (isDark ? _accent.withValues(alpha: 0.12) : const Color(0xFFFFF7F8)) : itemBg,
          borderRadius: BorderRadius.circular(8), // 16rpx
          border: Border.all(
            color: active ? _accent : (isDark ? const Color(0xFF2B2D33) : Colors.transparent),
            width: 1, // 2rpx
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(icon, width: 16, height: 16, fit: BoxFit.contain), // 32rpx
          const SizedBox(width: 7), // 14rpx
          Text(
            name,
            style: AppTextStyles.cn(
              15, // 30rpx
              color: active ? _accent : (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF555555)),
              weight: FontWeight.w500,
              height: 1,
            ),
          ),
        ]),
      ),
    );
  }
}
