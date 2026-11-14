import 'package:flutter/material.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../core/utils/screen_adapt.dart';

/// 意见反馈（表单）— 占位页
///
/// TODO: 对接 uni-app pages/user/center/feedback-form.vue 完整功能（反馈类型/内容/提交）。
/// 当前仅从持仓长按弹框「基金反馈」入口进入（type=sector，带基金编号/名称），展示占位空态。
class FeedbackFormPage extends StatelessWidget {
  final String type;
  final String fundCode;
  final String fundName;

  const FeedbackFormPage({
    super.key,
    this.type = '',
    this.fundCode = '',
    this.fundName = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final hint = fundName.isNotEmpty
        ? '反馈「$fundName${fundCode.isNotEmpty ? '（$fundCode）' : ''}」相关问题'
        : '意见反馈功能建设中';
    return Scaffold(
      backgroundColor: bg,
      appBar: CustomNavBar(title: '意见反馈', showBack: true),
      body: Center(
        child: Text(hint, style: AppTextStyles.cn(13.sx, color: textColor)),
      ),
    );
  }
}
