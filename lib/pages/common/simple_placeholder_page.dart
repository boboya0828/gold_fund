import 'package:flutter/material.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../core/utils/screen_adapt.dart';

/// 通用占位页 — 持仓详情页依赖的未移植子页统一占位（TODO 标注对应 uni-app 页面）
///
/// 用法见 router.dart 中各详情子路由（资金详情/收益排行/个股详情/诊基报告/积分中心）。
class SimplePlaceholderPage extends StatelessWidget {
  final String title;
  final String message;

  const SimplePlaceholderPage({
    super.key,
    required this.title,
    this.message = '页面功能建设中',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Scaffold(
      backgroundColor: bg,
      appBar: CustomNavBar(title: title, showBack: true),
      body: Center(
        child: Text(message, style: AppTextStyles.cn(13.sx, color: textColor)),
      ),
    );
  }
}
