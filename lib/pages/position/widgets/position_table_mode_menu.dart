import 'package:flutter/material.dart';

import '../../../features/position/providers/position_provider.dart'
    show TableShowMode;
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// Table mode popup matching the uni-app `.table-mode-menu`.
class PositionTableModeMenu extends StatelessWidget {
  final bool isDark;
  final TableShowMode currentMode;
  final ValueChanged<TableShowMode> onSelect;

  const PositionTableModeMenu({
    super.key,
    required this.isDark,
    required this.currentMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282B32) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(87)
                : const Color(0x291A2240),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _item(Icons.menu, '普通', TableShowMode.normal),
          _divider(),
          _item(Icons.format_list_bulleted, '简洁', TableShowMode.compact),
          _divider(),
          _item(Icons.more_horiz, '极简', TableShowMode.minimal),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, TableShowMode mode) {
    final isActive = currentMode == mode;
    final iconColor = isActive
        ? AppColors.primary
        : (isDark ? const Color(0xFF8F96A3) : const Color(0xFF888888));
    final textColor = isActive
        ? AppColors.primary
        : (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF555555));

    return GestureDetector(
      onTap: () => onSelect(mode),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.cn(
                14,
                color: textColor,
                weight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFF0F0F0),
    );
  }
}
