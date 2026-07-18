import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'fund_settings_confirm_dialog.dart';

/// 新建/编辑账本弹窗 — 1:1 复刻 uni-app components/create-book-modal.vue（bookApiType=asset）
///
/// up-modal：标题 + 输入框(maxlength 8，计数 n/8) + 取消/确认底栏；
/// 编辑模式附带 danger-row（删除账户 / 清空持仓），走 delectPopup 二次确认。
/// 接口（均为 ApiEndpoints 现有常量）：
///   创建 POST  assetBooks?bookName=      （createAssetBook）
///   重命名 PUT  assetBooks {bookId,newName}（renameAssetBook）
///   删除 DELETE assetBooks/{bookId}       （deleteAssetBook）
///   清空 DELETE assetBookClear/{bookId}   （clearAssetBook）
class FundSettingsBookModal extends StatefulWidget {
  final bool isDark;

  /// false=新建分组，true=编辑账户
  final bool editMode;

  /// 编辑时必传
  final int? bookId;
  final String initialName;

  const FundSettingsBookModal({
    super.key,
    required this.isDark,
    this.editMode = false,
    this.bookId,
    this.initialName = '',
  });

  /// 返回 true=操作成功(需刷新列表)，否则为取消/失败
  static Future<bool?> show(
    BuildContext context, {
    required bool isDark,
    bool editMode = false,
    int? bookId,
    String initialName = '',
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true, // closeOnClickOverlay
      builder: (_) => FundSettingsBookModal(
        isDark: isDark,
        editMode: editMode,
        bookId: bookId,
        initialName: initialName,
      ),
    );
  }

  @override
  State<FundSettingsBookModal> createState() => _FundSettingsBookModalState();
}

class _FundSettingsBookModalState extends State<FundSettingsBookModal> {
  static const _accent = AppColors.upColor; // #E05665
  final ApiClient _api = ApiClient();
  final TextEditingController _ctrl = TextEditingController();
  bool _submitting = false;

  String get _title => widget.editMode ? '编辑账户' : '新建分组';
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
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

  /// 源码 onConfirm：trim 校验 → 创建/重命名 → 成功关闭并回调 success
  Future<void> _onConfirm() async {
    if (_submitting) return;
    final nextName = _ctrl.text.trim();
    if (nextName.isEmpty) {
      _toast(_placeholder);
      return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.editMode) {
        final bookId = widget.bookId;
        if (bookId == null) {
          _toast('账户信息异常');
          if (mounted) setState(() => _submitting = false);
          return;
        }
        final res = await _api.put(ApiEndpoints.assetBooks, data: {'bookId': bookId, 'newName': nextName});
        _checkBizCode(res.data, '更新失败');
        _toast('更新成功');
      } else {
        final res = await _api.post('${ApiEndpoints.assetBooks}?bookName=${Uri.encodeComponent(nextName)}');
        _checkBizCode(res.data, '创建失败');
        _toast('创建成功');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(e is Exception ? e.toString().replaceFirst('Exception: ', '') : (widget.editMode ? '更新失败' : '创建失败'));
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 源码 onDeleteBook + confirmDeleteBook：delectPopup 确认后删除账本
  Future<void> _onDeleteBook() async {
    final bookId = widget.bookId;
    if (!widget.editMode || bookId == null || _submitting) return;
    final ok = await FundSettingsConfirmDialog.show(
      context,
      isDark: widget.isDark,
      title: '删除账户',
      content: '删除后不可恢复，确定删除当前账户吗？',
      confirmText: '确认删除',
    );
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    try {
      await _api.delete('${ApiEndpoints.assetBooks}/$bookId');
      _toast('删除成功');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _toast('删除失败');
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 源码 onDeleteDetail + confirmClearBook：delectPopup 确认后清空账本持仓
  Future<void> _onClearBook() async {
    final bookId = widget.bookId;
    if (!widget.editMode || bookId == null || _submitting) return;
    final ok = await FundSettingsConfirmDialog.show(
      context,
      isDark: widget.isDark,
      title: '清空持仓',
      content: '清空后当前账户下的持仓记录将被移除，确定继续吗？',
      confirmText: '确认清空',
    );
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    try {
      await _api.delete('${ApiEndpoints.assetBookClear}/$bookId');
      _toast('清空成功');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _toast('清空失败');
      if (mounted) setState(() => _submitting = false);
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
              // modal-content: padding 24rpx 0
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // input-wrapper: 400x80rpx, bg #f5f5f5, radius 16rpx, padding 0 20rpx
                    Container(
                      width: 200,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
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
                                hintStyle: AppTextStyles.cn(
                                  14,
                                  color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _ctrl.clear(),
                            child: const Padding(
                              padding: EdgeInsets.all(4), // 8rpx
                              child: Icon(Icons.cancel, size: 16, color: Color(0xFFCCCCCC)), // up-icon close-circle
                            ),
                          ),
                        ],
                      ),
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
                            style: AppTextStyles.cn(
                              11,
                              color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // danger-row（仅编辑模式）：删除账户 / 清空持仓
                    if (widget.editMode)
                      Container(
                        margin: const EdgeInsets.only(top: 10), // 20rpx
                        padding: const EdgeInsets.only(top: 10), // 20rpx
                        width: 251, // 对齐源码 danger-row 有效宽度（modal 502rpx）
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: divider, width: 0.5)), // 1rpx
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onDeleteBook,
                              child: Text(
                                '删除账户',
                                style: AppTextStyles.cn(
                                  14, // 28rpx
                                  color: isDark ? _accent : const Color(0xFF9B3843),
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onClearBook,
                              child: Text(
                                '清空持仓',
                                style: AppTextStyles.cn(
                                  14,
                                  color: isDark ? _accent : const Color(0xFF9B3843),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // 底栏按钮: 取消 | 确认 (u-modal button-group)
              Container(
                height: 44,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: divider, width: 0.5))),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _submitting ? null : () => Navigator.pop(context, false),
                        child: Center(
                          child: Text(
                            '取消',
                            style: AppTextStyles.cn(
                              15,
                              color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
                            ),
                          ),
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                                )
                              : Text('确认', style: AppTextStyles.cn(15, color: _accent)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
