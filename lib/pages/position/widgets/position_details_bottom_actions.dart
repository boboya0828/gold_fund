import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 底部操作栏
/// uni-app 对应: position-details.vue 的 .bottom-actionsa
class PositionDetailsBottomActions extends StatelessWidget {
  final bool isDark;
  final List<PdActionItem> actions;
  final ValueChanged<String> onTap; // 传 label

  const PositionDetailsBottomActions({
    super.key,
    required this.isDark,
    required this.actions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppColors.darkText : const Color(0xFF222222);
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 7 + MediaQuery.of(context).padding.bottom), // 16rpx 20rpx 14rpx+safe
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFEFEFEF), width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        for (final a in actions)
          if (a.type == 'button')
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(a.label),
                child: Container(
                  height: 35, // 70rpx
                  margin: const EdgeInsets.only(left: 6), // 12rpx gap
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: a.accent == 'sell' ? const Color(0xFFFDE4E8) : null,
                    gradient: a.accent == 'sell'
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFEE5668), Color(0xFFE74C62)],
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    a.label,
                    style: AppTextStyles.cn(14, color: a.accent == 'sell' ? const Color(0xFFE36074) : Colors.white, height: 1.0),
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => onTap(a.label),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 40, // 80rpx
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 22,
                    child: Icon(a.icon, size: a.iconSize, color: iconColor),
                  ),
                  Text(a.label, style: AppTextStyles.cn(10, color: iconColor, height: 1.2)),
                ]),
              ),
            ),
      ]),
    );
  }
}
