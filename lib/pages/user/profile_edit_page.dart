import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/text_styles.dart';

/// 个人资料编辑页 — 占位（头像/昵称/ID/皮肤切换待迁移）
/// uni-app 对应: pages/user/center/profile.vue
class ProfileEditPage extends ConsumerWidget {
  const ProfileEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('个人资料', style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(children: [
        const Expanded(child: Center(child: Text('个人资料页待迁移...'))),
        // 对齐 zdj profile.vue 的"安全设置"入口 — 退出登录/注销账号在其子页 settings.vue
        ListTile(
          title: Text('安全设置', style: AppTextStyles.cn(15, color: textColor)),
          trailing: Icon(Icons.chevron_right, color: textColor),
          onTap: () => context.push('/user/settings'),
        ),
      ]),
    );
  }
}
