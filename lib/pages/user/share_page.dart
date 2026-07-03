import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/text_styles.dart';

/// 分享 App 页 — 占位
/// uni-app 对应: pages/user/center/share.vue
class SharePage extends ConsumerWidget {
  const SharePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('分享App', style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: const Center(child: Text('分享功能待迁移...')),
    );
  }
}
