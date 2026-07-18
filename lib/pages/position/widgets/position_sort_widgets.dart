import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 排序页圆形勾选框 — 1:1 复刻 uni-app pages/positionv1/sort.vue .check-box
/// 32rpx 圆, 未选中: 1rpx #D6D6D6 边框白底; 选中: #E05665 底 + 白色对勾
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
        width: 16, // 32rpx
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? _accent : (isDark ? const Color(0xFF202125) : Colors.white),
          border: Border.all(
            color: checked ? _accent : (isDark ? const Color(0xFF4A4F58) : const Color(0xFFD6D6D6)),
            width: 1, // 2rpx
          ),
        ),
        child: checked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
      ),
    );
  }
}

/// 排序页底部操作栏 — 1:1 复刻 sort.vue .bottom-action-bar
/// 左侧「删除」(有选中时高亮) + 右侧「完成」(红色渐变)
class PositionSortBottomBar extends StatelessWidget {
  final int selectedCount;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onFinish;

  const PositionSortBottomBar({
    super.key,
    required this.selectedCount,
    required this.isDark,
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
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191D27) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              height: 38, // 76rpx
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // delete-btn: #E6E6E6/#A9A9A9; active: #FFECEF/#E05665
                color: hasSelection
                    ? (isDark ? _accent.withValues(alpha: 0.16) : const Color(0xFFFFECEF))
                    : (isDark ? const Color(0xFF282828) : const Color(0xFFE6E6E6)),
                borderRadius: BorderRadius.circular(19), // 38rpx
              ),
              child: Text(
                '删除',
                style: AppTextStyles.cn(
                  14, // 28rpx
                  weight: FontWeight.w600,
                  color: hasSelection ? _accent : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA9A9A9)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9), // gap 18rpx
        Expanded(
          child: GestureDetector(
            onTap: onFinish,
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // finish-btn: linear-gradient(135deg, #E05665 0%, #F06B78 100%); 深色纯色
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE05665), Color(0xFFF06B78)],
                      ),
                color: isDark ? _accent : null,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Text('完成', style: AppTextStyles.cn(14, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}
