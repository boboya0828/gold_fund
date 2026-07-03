import 'package:flutter/material.dart';

import '../../core/services/app_update_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 更新弹窗 - 对齐 uni-app components/UpdatePopup.vue
///
/// 展示版本号、更新说明、更新列表；"立即更新"打开下载/商店地址；
/// 非强制更新时提供"稍后再说"（记录 24h 跳过）。
class UpdatePopup extends StatelessWidget {
  final AppUpdateInfo info;

  const UpdatePopup({super.key, required this.info});

  /// 便捷方法：弹出更新弹窗
  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdatePopup(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF888888);

    return PopScope(
      canPop: !info.forceUpdate,
      child: Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 标题
            Center(child: Text(info.title, style: AppTextStyles.cn(17, color: textColor, weight: FontWeight.w600))),
            if (info.versionName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(child: Text('v${info.versionName}', style: AppTextStyles.cn(12, color: subColor))),
            ],
            const SizedBox(height: 16),
            // 更新说明 / 列表
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (info.updateList.isNotEmpty)
                    ...info.updateList.map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('· ', style: AppTextStyles.cn(14, color: subColor)),
                            Expanded(child: Text(line, style: AppTextStyles.cn(14, color: textColor, height: 1.4))),
                          ]),
                        ))
                  else
                    Text(info.description, style: AppTextStyles.cn(14, color: textColor, height: 1.4)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            // 按钮
            Row(children: [
              if (!info.forceUpdate) ...[
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await AppUpdateService.markSkipped(info);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: subColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: isDark ? const Color(0xFF2A2C31) : const Color(0xFFF2F2F2),
                    ),
                    child: const Text('稍后再说'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final ok = await AppUpdateService.openUpdateUrl(info);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('更新地址已复制'), duration: Duration(seconds: 2)),
                      );
                    }
                    if (!info.forceUpdate) Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('立即更新'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
