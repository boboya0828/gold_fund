import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 安全设置页 — 1:1 复刻 uni-app pages/user/center/settings.vue
/// 退出登录 / 注销账号入口在此，而非"我的"首页。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _versionText = '--';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final pkg = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _versionText = 'V${pkg.version}（${pkg.buildNumber}）');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFFAF7F7);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final valueColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999);
    final dividerColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEEEEE);
    final phone = ref.watch(authProvider).user?.phoneNumber;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          CustomNavBar(title: '安全设置', showBack: true, backgroundColor: bg, titleColor: textColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(children: [
                const SizedBox(height: 10),
                _listItem(
                  label: '手机绑定',
                  value: (phone == null || phone.isEmpty) ? '暂未绑定' : phone,
                  valueColor: valueColor, textColor: textColor, dividerColor: dividerColor,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中'), duration: Duration(seconds: 1)),
                  ),
                ),
                _listItem(
                  label: '当前版本', value: _versionText,
                  valueColor: valueColor, textColor: textColor, dividerColor: dividerColor,
                  showArrow: false, isLast: true,
                ),
                const Spacer(),
                SizedBox(
                  width: 287, height: 45,
                  child: ElevatedButton(
                    onPressed: () => _showConfirm('确认退出登录吗？', _logout),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.upColor, foregroundColor: Colors.white,
                      shape: const StadiumBorder(), elevation: 0,
                    ),
                    child: const Text('退出登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showConfirm('注销后账号将无法恢复，相关数据、资产及权益将被清空且无法找回。如因使用问题可联系客服，确认仍要注销吗？', _logout),
                  child: Text('注销账号', style: TextStyle(fontSize: 13, color: valueColor)),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _listItem({
    required String label,
    required String value,
    required Color valueColor,
    required Color textColor,
    required Color dividerColor,
    bool showArrow = true,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor, width: 0.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: AppTextStyles.cn(15, color: textColor)),
          Row(children: [
            Text(value, style: AppTextStyles.cn(14, color: valueColor)),
            if (showArrow) ...[
              const SizedBox(width: 6),
              Image.asset('assets/images/img/right-ico.png', width: 6.5, height: 12),
            ],
          ]),
        ]),
      ),
    );
  }

  void _showConfirm(String content, VoidCallback onConfirm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF202125) : Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(content, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SizedBox(height: 40, child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
                  side: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEEEEE)),
                  shape: const StadiumBorder()),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); onConfirm(); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.upColor, foregroundColor: Colors.white,
                  shape: const StadiumBorder(), elevation: 0),
                child: const Text('确认', style: TextStyle(fontSize: 14)),
              ))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/home');
  }
}
