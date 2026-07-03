import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 账本选择下拉菜单 — 1:1 复刻 uni-app .asset-book-menu
class BookSelectorMenu extends StatelessWidget {
  final bool isDark;
  final List<String> books;
  final String selectedBook;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;

  const BookSelectorMenu({
    super.key,
    required this.isDark,
    required this.books,
    required this.selectedBook,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
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
          children: books.map((book) {
            final isActive = book == selectedBook;
            return GestureDetector(
              onTap: () => onSelected(book),
              child: Container(
                height: 29, // 58rpx
                padding: const EdgeInsets.symmetric(horizontal: 11), // 22rpx
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.menuItemBorderDark : AppColors.menuItemBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Text(
                  book,
                  style: TextStyle(
                    fontSize: 12, // 24rpx
                    color: isActive
                        ? AppColors.primary
                        : (isDark ? AppColors.darkText : const Color(0xFF4E4E4E)),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
