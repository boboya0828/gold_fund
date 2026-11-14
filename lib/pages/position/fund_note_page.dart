import 'package:flutter/material.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../core/utils/screen_adapt.dart';

/// 基金笔记 — 占位页
///
/// TODO: 对接 uni-app pages/positionv1/sub/fund-note.vue 完整功能（笔记列表/编辑）。
/// 当前仅从持仓长按弹框「基金笔记」入口进入，展示占位空态。
class FundNotePage extends StatelessWidget {
  final String symbolId;
  final String symbolCode;
  final String fundName;

  const FundNotePage({
    super.key,
    this.symbolId = '',
    this.symbolCode = '',
    this.fundName = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Scaffold(
      backgroundColor: bg,
      appBar: CustomNavBar(title: '基金笔记', showBack: true),
      body: Center(
        child: Text(
          fundName.isNotEmpty ? '「$fundName」的笔记功能建设中' : '笔记功能建设中',
          style: AppTextStyles.cn(13.sx, color: textColor),
        ),
      ),
    );
  }
}
