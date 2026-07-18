import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';

/// 快捷菜单面板 — 1:1 复刻 .quick-menu-panel
/// uni-app: width:230rpx(115px), padding:8rpx(4px) 0, border-radius:16rpx(8px)
/// 菜单项: 同步持仓(plus,17) / 批量同步(icon-fuzhiyemian,17) / 交易记录(icon-jilu,16)
///         资产分析(icon-tongji,15) / 账本管理(gear,16)
class PositionQuickMenu extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSync;
  final VoidCallback onBatchSync;
  final VoidCallback onTradeRecord;
  final VoidCallback onAnalysis;
  final VoidCallback onLedger;

  const PositionQuickMenu({
    super.key,
    required this.isDark,
    required this.onSync,
    required this.onBatchSync,
    required this.onTradeRecord,
    required this.onAnalysis,
    required this.onLedger,
  });

  @override
  Widget build(BuildContext context) {
    final menuTextColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF26304D);
    final menuIconColor = isDark ? const Color(0xFFAEB4C0) : const Color(0xFF4A5168);
    final dividerColor = isDark ? const Color(0xFF3A3E48) : const Color(0xFFEEF1F5);

    return Container(
      width: 115, // 230rpx
      padding: const EdgeInsets.symmetric(vertical: 4), // 8rpx 0
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282B32) : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        // 源码浅色 .quick-menu-panel 无阴影，仅深色有
        boxShadow: isDark
            ? [BoxShadow(color: Colors.black.withAlpha(87), blurRadius: 17)]
            : null,
      ),
      child: Column(children: [
        _item(AppIcons.add, 17, '同步持仓', menuTextColor, menuIconColor, onSync),
        _divider(dividerColor),
        _item(AppIcons.copyPage, 17, '批量同步', menuTextColor, menuIconColor, onBatchSync),
        _divider(dividerColor),
        _item(AppIcons.record, 16, '交易记录', menuTextColor, menuIconColor, onTradeRecord),
        _divider(dividerColor),
        _item(AppIcons.statistics, 15, '资产分析', menuTextColor, menuIconColor, onAnalysis),
        _divider(dividerColor),
        _item(AppIcons.settings, 16, '账本管理', menuTextColor, menuIconColor, onLedger),
      ]),
    );
  }

  Widget _item(IconData icon, double iconSize, String label, Color textColor,
      Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44, // 88rpx
        padding: const EdgeInsets.symmetric(horizontal: 12), // 0 24rpx
        child: Row(children: [
          // 源码 .quick-menu-item__icon: 34rpx(17px) 容器 + margin-right 16rpx(8px)
          SizedBox(
            width: 17,
            height: 17,
            child: Center(
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.cn(12, color: textColor)), // 24rpx
        ]),
      ),
    );
  }

  Widget _divider(Color color) {
    // uni-app divider: left:72rpx(36px), right:24rpx(12px), height:1px(0.5px)
    return Container(height: 0.5, margin: const EdgeInsets.only(left: 36, right: 12), color: color);
  }
}
