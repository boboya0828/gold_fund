import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 批量加减仓页辅助组件 — 1:1 复刻 uni-app pages/positionv1/batch-adjust.vue
/// 的底部操作栏与两个 up-modal 弹窗（金额输入 / 二次确认）。
///
/// 弹窗样式对应页面内对 uview-plus u-modal 的覆盖：
///   圆角 24rpx、标题 32rpx 加粗、按钮组高 96rpx、取消 #7F7A7B / 确认 #E05665。
/// 数字键盘复用 lib/pages/fund/upload/madd_number_keyboard.dart（同一 uni-app
/// 组件 CustomNumberKeyboard.vue 的既有复刻），键盘在页面 Stack 中位于弹窗之上，
/// 与 uni-app 中 keyboard z-index 高于 popup 的层叠关系一致。

const _kAccent = Color(0xFFE05665);

/// 底部操作栏 — .bottom-action-bar
/// 普通态: [批量减仓(选中时高亮)] [批量加仓]; 编辑态: [取消] [提交]
class BatchAdjustBottomBar extends StatelessWidget {
  final bool isEditingAmounts;
  final int selectedCount;
  final bool isDark;
  final VoidCallback onBatchSell;
  final VoidCallback onBatchBuy;
  final VoidCallback onCancelEdit;
  final VoidCallback onEditSubmit;

  const BatchAdjustBottomBar({
    super.key,
    required this.isEditingAmounts,
    required this.selectedCount,
    required this.isDark,
    required this.onBatchSell,
    required this.onBatchBuy,
    required this.onCancelEdit,
    required this.onEditSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      // padding 16rpx 24rpx + env(safe-area-inset-bottom); 阴影 0 -6rpx 20rpx
      padding: EdgeInsets.fromLTRB(12.sx, 8.sx, 12.sx, 8.sx + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191D27) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.sx,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        if (isEditingAmounts) ...[
          Expanded(child: _cancelBtn()),
          SizedBox(width: 9.sx), // gap 18rpx
          Expanded(child: _buyBtn('提交', onEditSubmit)),
        ] else ...[
          Expanded(child: _sellBtn()),
          SizedBox(width: 9.sx),
          Expanded(child: _buyBtn('批量加仓', onBatchBuy)),
        ],
      ]),
    );
  }

  /// .batch-sell-btn / .batch-sell-btn--active
  Widget _sellBtn() {
    final active = selectedCount > 0;
    return GestureDetector(
      onTap: onBatchSell,
      child: Container(
        height: 38.sx, // 76rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? _kAccent.withValues(alpha: 0.16) : const Color(0xFFFFECEF))
              : (isDark ? const Color(0xFF282828) : const Color(0xFFE6E6E6)),
          borderRadius: BorderRadius.circular(19.sx), // 38rpx
        ),
        child: Text(
          '批量减仓',
          style: AppTextStyles.cn(
            14.sx, // 28rpx
            weight: FontWeight.w600,
            color: active ? _kAccent : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA9A9A9)),
          ),
        ),
      ),
    );
  }

  /// .batch-buy-btn (浅色渐变 135deg #E05665→#F06B78, 深色纯色)
  Widget _buyBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38.sx,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE05665), Color(0xFFF06B78)],
                ),
          color: isDark ? _kAccent : null,
          borderRadius: BorderRadius.circular(19.sx),
        ),
        child: Text(text, style: AppTextStyles.cn(14.sx, weight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  /// .cancel-btn
  Widget _cancelBtn() {
    return GestureDetector(
      onTap: onCancelEdit,
      child: Container(
        height: 38.sx,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282828) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(19.sx),
        ),
        child: Text(
          '取消',
          style: AppTextStyles.cn(
            14.sx,
            weight: FontWeight.w600,
            color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

/// up-modal 通用外壳 — .batch-adjust-modal 覆盖样式
/// 宽 [width]、圆角 24rpx=12、标题 32rpx 加粗、按钮组 96rpx、取消/确认双按钮
class BatchAdjustModalShell extends StatelessWidget {
  final String title;
  final double width;
  final bool isDark;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Widget child;

  const BatchAdjustModalShell({
    super.key,
    required this.title,
    required this.width,
    required this.isDark,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF3A3E48) : const Color(0xFFEBE4E4);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202125) : Colors.white,
            borderRadius: BorderRadius.circular(12.sx), // 24rpx
            boxShadow: [
              BoxShadow(
                // 0 26rpx 80rpx rgba(32,25,26,0.18) / 深色 rgba(0,0,0,0.42)
                color: isDark ? Colors.black.withValues(alpha: 0.42) : const Color(0x2E20191A),
                blurRadius: 40.sx,
                offset: Offset(0, 13.sx),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: EdgeInsets.only(top: 19.sx), // title padding-top 38rpx
              child: Text(
                title,
                style: AppTextStyles.cn(
                  16.sx, // 32rpx
                  weight: FontWeight.w700,
                  color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
                  height: 1.2,
                ),
              ),
            ),
            child,
            // 按钮组: 高 96rpx, 上边框 + 中间竖线 (u-line)
            Container(
              height: 48.sx, // 96rpx
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider, width: 0.5)),
              ),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCancel,
                    child: Center(
                      child: Text(
                        cancelText,
                        style: AppTextStyles.cn(
                          15.sx, // 30rpx
                          weight: FontWeight.w600,
                          color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7F7A7B),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 0.5, color: divider),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onConfirm,
                    child: Center(
                      child: Text(
                        confirmText,
                        style: AppTextStyles.cn(15.sx, weight: FontWeight.w600, color: _kAccent),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 金额输入弹框 — up-modal (width 550rpx, 取消/完成)
/// [onOpenKeyboard] 点击输入框时回调（打开自定义数字键盘 target=modal）
class BatchAdjustAmountModal extends StatelessWidget {
  final String title;
  final String amountInput;
  final String amountPrefixText; // ¥ / -¥
  final String tipText; // 每只基金统一加仓/减仓
  final bool isDark;
  final VoidCallback onOpenKeyboard;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const BatchAdjustAmountModal({
    super.key,
    required this.title,
    required this.amountInput,
    required this.amountPrefixText,
    required this.tipText,
    required this.isDark,
    required this.onOpenKeyboard,
    required this.onClear,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return BatchAdjustModalShell(
      title: title,
      width: 275.sx, // 550rpx
      isDark: isDark,
      cancelText: '取消',
      confirmText: '完成',
      onCancel: onCancel,
      onConfirm: onConfirm,
      child: Padding(
        padding: EdgeInsets.only(top: 12.sx, bottom: 11.sx), // 24rpx 0 22rpx
        child: Column(children: [
          // .amount-input-wrap: 400rpx x 80rpx, bg #F5F5F5, radius 16rpx
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenKeyboard,
            child: Container(
              width: 200.sx, // 400rpx
              height: 40.sx, // 80rpx
              padding: EdgeInsets.symmetric(horizontal: 10.sx), // 0 20rpx
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8.sx), // 16rpx
              ),
              child: Row(children: [
                Text(
                  amountPrefixText,
                  style: AppTextStyles.cn(
                    14.sx, // 28rpx
                    weight: FontWeight.w500,
                    color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
                  ),
                ),
                SizedBox(width: 4.sx), // margin-right 8rpx
                Expanded(
                  child: Text(
                    amountInput.isEmpty ? '请输入金额' : amountInput,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: amountInput.isEmpty
                        ? AppTextStyles.cn(14.sx, color: const Color(0xFF999999)) // .amount-placeholder
                        : AppTextStyles.num(
                            14.sx, // 28rpx numFamily
                            color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
                          ),
                  ),
                ),
                if (amountInput.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: Padding(
                      padding: EdgeInsets.all(4.sx), // 8rpx, margin-right -8rpx 忽略
                      child: Icon(Icons.cancel, size: 16.sx, color: Color(0xFFCCCCCC)), // up-icon close-circle
                    ),
                  ),
              ]),
            ),
          ),
          // .amount-modal-tip
          Container(
            width: 200.sx, // 400rpx
            margin: EdgeInsets.only(top: 4.sx), // 8rpx
            alignment: Alignment.centerRight,
            child: Text(
              tipText,
              style: AppTextStyles.cn(
                11.sx, // 22rpx
                color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999),
                height: 1.0,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 二次确认弹框 — up-modal (width 620rpx, 再想想/提交)
class BatchAdjustConfirmModal extends StatelessWidget {
  final String content;
  final bool isDark;
  final VoidCallback onCancel; // 再想想
  final VoidCallback onConfirm; // 提交

  const BatchAdjustConfirmModal({
    super.key,
    required this.content,
    required this.isDark,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return BatchAdjustModalShell(
      title: '确认提交',
      width: 310.sx, // 620rpx
      isDark: isDark,
      cancelText: '再想想',
      confirmText: '提交',
      onCancel: onCancel,
      onConfirm: onConfirm,
      child: Padding(
        padding: EdgeInsets.fromLTRB(19.sx, 14.sx, 19.sx, 23.sx), // 28rpx 38rpx 46rpx
        child: Column(children: [
          // .confirm-modal-icon: 64rpx 圆, #FFF0F2 / 深色 rgba(224,86,101,0.16)
          Container(
            width: 32.sx, // 64rpx
            height: 32.sx,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? _kAccent.withValues(alpha: 0.16) : const Color(0xFFFFF0F2),
            ),
            child: Icon(Icons.info, size: 24.sx, color: _kAccent), // uni-icons info
          ),
          SizedBox(height: 11.sx), // gap 22rpx
          Text(
            content,
            textAlign: TextAlign.center,
            style: AppTextStyles.cn(
              14.sx, // 28rpx
              weight: FontWeight.w500,
              color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
              height: 1.65,
            ),
          ),
        ]),
      ),
    );
  }
}
