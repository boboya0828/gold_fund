import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 账本选项 (value: 'all' 或 bookId 字符串) — 对齐 uni-app homeBookOptions
class BookOption {
  final String value;
  final String label;
  const BookOption({required this.value, required this.label});
}

/// 账本选择下拉菜单 — 1:1 复刻 uni-app .asset-book-menu
class BookSelectorMenu extends StatelessWidget {
  final bool isDark;
  final List<BookOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;

  const BookSelectorMenu({
    super.key,
    required this.isDark,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 激活色: 浅 #E05665 / 深 #EA5D70
    final activeColor = isDark ? const Color(0xFFEA5D70) : AppColors.upColor;
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        width: 105, // 210rpx
        decoration: BoxDecoration(
          color: isDark ? AppColors.menuBgDark : AppColors.white,
          borderRadius: BorderRadius.circular(4), // 8rpx
          boxShadow: [
            BoxShadow(
              color: isDark ? AppColors.menuShadowDark : AppColors.menuShadowLight,
              blurRadius: 14, offset: const Offset(0, 6), // 0 12rpx 28rpx
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8), // 16rpx
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              _buildItem(options[i], i == options.length - 1, activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BookOption option, bool isLast, Color activeColor) {
    final isActive = option.value == selectedValue;
    return GestureDetector(
      onTap: () => onSelected(option.value),
      child: Container(
        height: 29, // 58rpx
        padding: const EdgeInsets.symmetric(horizontal: 11), // 22rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // :last-child 无下边框
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.menuItemBorderDark : AppColors.menuItemBorder,
                    width: 0.5,
                  ),
                ),
        ),
        child: Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12, // 24rpx
            color: isActive
                ? activeColor
                : (isDark ? AppColors.darkText : const Color(0xFF4E4E4E)),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
