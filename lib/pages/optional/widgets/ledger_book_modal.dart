import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import 'ledger_book_api.dart';

/// 新建/编辑账本弹窗 — 1:1 复刻 uni-app components/create-book-modal.vue
/// up-modal: 标题 + 输入框(maxlength 8, 计数 n/8) + 取消/确认底栏
/// 注: 源码 danger-row（删除账户/清空xx）仅在 showDangerActions=true 时可见,
///     而两个 ledger 页均传 false, 故此处不实现该区块（见迁移报告）。
class LedgerBookModal extends StatefulWidget {
  final bool isDark;
  final LedgerBookType bookType;

  /// false=新建分组, true=编辑账户
  final bool editMode;

  /// 编辑时必传（默认账本为 0）
  final int? bookId;
  final String initialName;
  final bool isDefault;

  const LedgerBookModal({
    super.key,
    required this.isDark,
    required this.bookType,
    this.editMode = false,
    this.bookId,
    this.initialName = '',
    this.isDefault = false,
  });

  /// 返回 true=保存成功(需刷新列表), 否则为取消/失败
  static Future<bool?> show(
    BuildContext context, {
    required bool isDark,
    required LedgerBookType bookType,
    bool editMode = false,
    int? bookId,
    String initialName = '',
    bool isDefault = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true, // closeOnClickOverlay
      builder: (_) => LedgerBookModal(
        isDark: isDark,
        bookType: bookType,
        editMode: editMode,
        bookId: bookId,
        initialName: initialName,
        isDefault: isDefault,
      ),
    );
  }

  @override
  State<LedgerBookModal> createState() => _LedgerBookModalState();
}

class _LedgerBookModalState extends State<LedgerBookModal> {
  static const _accent = Color(0xFFE05665);
  final TextEditingController _ctrl = TextEditingController();
  bool _submitting = false;

  String get _title {
    if (widget.editMode && widget.isDefault) return '编辑默认账户';
    return widget.editMode ? '编辑账户' : '新建分组';
  }

  String get _placeholder => widget.editMode ? '请输入账户名称' : '请输入分组名称';

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialName;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  /// uni-app onConfirm: trim 校验 → rename/create → 成功关闭并回调 success
  Future<void> _onConfirm() async {
    if (_submitting) return;
    final nextName = _ctrl.text.trim();
    if (nextName.isEmpty) {
      _toast(_placeholder);
      return;
    }
    setState(() => _submitting = true);
    final api = LedgerBookApi(widget.bookType);
    try {
      if (widget.editMode) {
        final bookId = widget.bookId;
        if (bookId == null) {
          _toast('账户信息异常');
          if (mounted) setState(() => _submitting = false);
          return;
        }
        final res = await api.renameBook(bookId, nextName);
        _checkBizCode(res.data, '更新失败');
        _toast('更新成功');
      } else {
        final res = await api.createBook(nextName);
        _checkBizCode(res.data, '创建失败');
        _toast('创建成功');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(e is Exception ? e.toString().replaceFirst('Exception: ', '') : (widget.editMode ? '更新失败' : '创建失败'));
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// uni-app: res.code 存在且非 200/0 时视为业务失败
  void _checkBizCode(dynamic data, String fallback) {
    if (data is Map && data['code'] != null) {
      final code = data['code'];
      if (code != 200 && code != 0) {
        throw Exception(data['message']?.toString() ?? fallback);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F0F0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 275, // 550rpx
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(_title, style: AppTextStyles.cn(15, color: textColor, weight: FontWeight.w600)),
              // modal-content: padding 24rpx 0 → v12
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  // input-wrapper: 400x80rpx, bg #f5f5f5, radius 16rpx, padding 0 20rpx
                  Container(
                    width: 200,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLength: 8,
                          style: AppTextStyles.cn(14, color: textColor), // 28rpx
                          cursorColor: _accent,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            counterText: '',
                            hintText: _placeholder,
                            hintStyle: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999)),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _ctrl.clear(),
                        child: const Padding(
                          padding: EdgeInsets.all(4), // 8rpx
                          child: Icon(Icons.cancel, size: 16, color: Color(0xFFCCCCCC)), // up-icon close-circle
                        ),
                      ),
                    ]),
                  ),
                  // char-count: 右对齐 22rpx #999, margin-top 8rpx
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 200,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _ctrl,
                        builder: (_, v, _) => Text(
                          '${v.text.characters.length}/8',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              // 底栏按钮: 取消 | 确认 (u-modal button-group)
              Container(
                height: 44,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: divider, width: 0.5))),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _submitting ? null : () => Navigator.pop(context, false),
                      child: Center(
                        child: Text('取消',
                            style: AppTextStyles.cn(15, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666))),
                      ),
                    ),
                  ),
                  Container(width: 0.5, color: divider),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onConfirm,
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                            : Text('确认', style: AppTextStyles.cn(15, color: _accent)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
