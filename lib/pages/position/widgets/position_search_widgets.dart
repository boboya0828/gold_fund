import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 搜索页分节标题 — 1:1 复刻 uni-app pages/positionv1/search.vue .section-head
/// 左侧标题(26rpx #767676), 右侧可选操作区(如清空历史垃圾桶)
class PositionSearchSectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? action;

  const PositionSearchSectionHeader({super.key, required this.title, required this.isDark, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 11.sx), // margin-bottom 22rpx
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: AppTextStyles.cn(13.sx, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF767676))), // 26rpx
        ),
        ?action,
      ]),
    );
  }
}

/// 搜索历史标签 — 1:1 复刻 search.vue .history-tag
/// padding 12rpx 22rpx, radius 999, 白底, 24rpx #767676
class PositionSearchHistoryTag extends StatelessWidget {
  final String text;
  final bool isDark;
  final VoidCallback onTap;

  const PositionSearchHistoryTag({super.key, required this.text, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.sx, vertical: 6.sx), // 22rpx 12rpx
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282828) : Colors.white,
          borderRadius: BorderRadius.circular(999.sx),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.cn(12.sx, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF767676)), // 24rpx
        ),
      ),
    );
  }
}
