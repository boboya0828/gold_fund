import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 排序页圆形勾选框 — 1:1 复刻 uni-app pages/positionv1/sub/sort.vue .check-box
/// 32rpx 圆, 未选中: 2rpx #D6D6D6 边框白底; 选中: #E05665 底 + 白色对勾(checkmarkempty size 16px)
class PositionSortCheckBox extends StatelessWidget {
  final bool checked;
  final bool isDark;
  final VoidCallback onTap;

  const PositionSortCheckBox({super.key, required this.checked, required this.isDark, required this.onTap});

  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 16.sx, // 32rpx
        height: 16.sx,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? _accent : (isDark ? const Color(0xFF202125) : Colors.white),
          border: Border.all(
            color: checked ? _accent : (isDark ? const Color(0xFF4A4F58) : const Color(0xFFD6D6D6)),
            width: 1.sx, // 2rpx
          ),
        ),
        child: checked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}

/// 排序页底部操作栏 — 1:1 复刻 sort.vue .bottom-action-bar（排序 tab）
/// 三枚按钮：移动分组 / 删除 / 完成（gap 18rpx）
/// - move/delete：#E6E6E6/#A9A9A9（深 #282828/#A7ADB8）；有选中时 #FFECEF/#E05665（深 rgba(224,86,101,0.16)）
/// - 完成：linear-gradient(135deg, #E05665, #F06B78)，无改动(sortDirty=false)浅红 #F3B4BB；深色恒 #E05665
class PositionSortBottomBar extends StatelessWidget {
  final int selectedCount;
  final bool sortDirty;
  final bool deleting;
  final bool isDark;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onFinish;

  const PositionSortBottomBar({
    super.key,
    required this.selectedCount,
    required this.sortDirty,
    required this.deleting,
    required this.isDark,
    required this.onMove,
    required this.onDelete,
    required this.onFinish,
  });

  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      // padding 16rpx 24rpx + safe-area; 阴影 0 -6rpx 20rpx
      padding: EdgeInsets.fromLTRB(12.sx, 8.sx, 12.sx, 8.sx + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191D27) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.sx,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(child: _actionBtn(
          label: '移动分组',
          active: hasSelection,
          onTap: onMove,
        )),
        SizedBox(width: 9.sx), // gap 18rpx
        Expanded(child: _actionBtn(
          label: deleting ? '删除中...' : '删除',
          active: hasSelection && !deleting,
          onTap: onDelete,
        )),
        SizedBox(width: 9.sx),
        Expanded(child: _finishBtn(
          label: '完成',
          idle: !sortDirty,
          onTap: onFinish,
        )),
      ]),
    );
  }

  /// .bottom-btn: flex 1, height 76rpx, radius 38rpx, 28rpx 600
  Widget _actionBtn({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38.sx, // 76rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? _accent.withValues(alpha: 0.16) : const Color(0xFFFFECEF))
              : (isDark ? const Color(0xFF282828) : const Color(0xFFE6E6E6)),
          borderRadius: BorderRadius.circular(19.sx), // 38rpx
        ),
        child: Text(
          label,
          style: AppTextStyles.cn(
            14.sx, // 28rpx
            weight: FontWeight.w600,
            color: active ? _accent : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA9A9A9)),
          ),
        ),
      ),
    );
  }

  /// .finish-btn: 渐变红；--idle 浅红 #F3B4BB；深色恒 #E05665
  Widget _finishBtn({required String label, required bool idle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38.sx,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : (idle
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE05665), Color(0xFFF06B78)],
                    )),
          color: isDark ? _accent : (idle ? const Color(0xFFF3B4BB) : null),
          borderRadius: BorderRadius.circular(19.sx),
        ),
        child: Text(label,
            style: AppTextStyles.cn(14.sx, weight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}

/// 表头管理底部完成栏 — 1:1 复刻 sort.vue columns tab 的 finish-btn（宽 100%）
/// 保存中 0.6 透明度禁用；无改动(columnsDirty=false)浅红 #F3B4BB；深色恒 #E05665
class PositionColumnsFinishBar extends StatelessWidget {
  final bool dirty;
  final bool saving;
  final bool isDark;
  final VoidCallback onFinish;

  const PositionColumnsFinishBar({
    super.key,
    required this.dirty,
    required this.saving,
    required this.isDark,
    required this.onFinish,
  });

  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12.sx, 8.sx, 12.sx, 8.sx + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191D27) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.sx,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: saving ? null : onFinish,
        child: Opacity(
          opacity: saving ? 0.6 : 1, // columns-finish-btn--saving
          child: Container(
            width: double.infinity,
            height: 38.sx, // 76rpx
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : (dirty
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE05665), Color(0xFFF06B78)],
                        )
                      : null),
              color: isDark ? _accent : (dirty ? null : const Color(0xFFF3B4BB)),
              borderRadius: BorderRadius.circular(19.sx),
            ),
            child: Text(
              saving ? '保存中...' : '完成',
              style: AppTextStyles.cn(14.sx, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
