import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 删除确认弹窗 — 1:1 复刻 uni-app DelectPopup 组件
class PositionDeleteDialog extends StatelessWidget {
  final String assetName;
  final bool isDark;

  const PositionDeleteDialog({super.key, required this.assetName, required this.isDark});

  static Future<bool?> show(BuildContext context, {required String assetName, required bool isDark}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => PositionDeleteDialog(assetName: assetName, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282B32) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 20),
            Text('确认删除',
              style: AppTextStyles.cn(16, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333), weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('确定要删除「$assetName」吗？',
                style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666)),
                textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            Divider(height: 0.5, color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFEEEEEE)),
            SizedBox(
              height: 48,
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Center(
                      child: Text('取消', style: AppTextStyles.cn(15, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999))),
                    ),
                  ),
                ),
                Container(width: 0.5, height: 48, color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFEEEEEE)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Center(
                      child: Text('确认删除', style: AppTextStyles.cn(15, color: AppColors.primary, weight: FontWeight.w500)),
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

