import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/services/app_update_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/widgets/update_popup.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 我的页面 - 1:1 复刻 uni-app pages/user/index.vue (来自 wxapp-yjzs)
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    // 用户信息以 authProvider 为唯一数据源 (对齐 vue userInfo)，
    // 登录/登出后这里会自动同步刷新，不再手动读取从未写入过的 SharedPreferences 'userInfo' 键。
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final hasUser = authState.isAuthenticated && user != null;
    final avatar = user?.avatarUrl ?? '';
    final nickname = (user?.nickname?.isNotEmpty ?? false) ? user!.nickname! : '用户';
    final phone = user?.phoneNumber ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final dividerColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF6F6F6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            decoration: isDark ? null : const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/img/position-bg1.png'), fit: BoxFit.fitWidth, alignment: Alignment.topCenter),
            ),
            child: Column(children: [
              // Title
              Container(
                margin: EdgeInsets.only(top: topPad + 5),
                alignment: Alignment.center,
                child: Text('我的', style: AppTextStyles.cn(18, color: textColor)),
              ),
              const SizedBox(height: 25),
              // ===== User Profile Card =====
              GestureDetector(
                onTap: () {
                  final auth = ref.read(authProvider);
                  if (!auth.isAuthenticated) {
                    context.push('/login');
                  } else {
                    context.push('/user/profile');
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    // Avatar — 对齐 wxapp-yjzs：无 avatarUrl 时回退本地 photo.png
                    ClipOval(
                      child: avatar.isNotEmpty
                          ? Image.network(avatar, width: 52, height: 52, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Image.asset('assets/images/img/photo.png', width: 52, height: 52, fit: BoxFit.cover))
                          : Image.asset('assets/images/img/photo.png', width: 52, height: 52, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 15),
                    // Name + phone
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (hasUser) ...[
                          Text(nickname, style: AppTextStyles.cn(16, color: const Color(0xFF232323), weight: FontWeight.bold)),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(phone, style: AppTextStyles.cn(12, color: const Color(0xFF868686))),
                          ],
                        ] else
                          Text('登录/注册', style: AppTextStyles.cn(19, color: textColor)),
                      ]),
                    ),
                    Image.asset('assets/images/img/right-ico1.png', width: 5.5, height: 10),
                  ]),
                ),
              ),
              const SizedBox(height: 21),
              // ===== 盈亏分析 =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(5)),
                child: _menuRow('uico7', '盈亏分析', dividerColor, isDark, () {
                  final auth = ref.read(authProvider);
                  if (!auth.isAuthenticated) {
                    context.push('/login');
                  } else {
                    context.push('/user/curve');
                  }
                }),
              ),
              const SizedBox(height: 12),
              // ===== 功能菜单 =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(5)),
                // 意见反馈：源码此项已停用（注释）且无后端接口，故不展示
                child: Column(children: [
                  _menuRow('uico4', '分享App', dividerColor, isDark, () => context.push('/user/share')),
                  _menuRow('uico5', '隐私政策', dividerColor, isDark, () => context.push('/privacy')),
                  _menuRow('uico1', '用户协议', dividerColor, isDark, () => context.push('/agreement')),
                  _menuRow('uico6', '检查更新', null, isDark, _handleCheckUpdate),
                ]),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ),
    );
  }

  /// 功能菜单行 - iconBase 为图标基名 (如 uico4)，深色模式加载本地 -b 变体 (对齐 zdj getUserIcon)
  Widget _menuRow(String iconBase, String label, Color? dividerColor, bool isDark, VoidCallback onTap) {
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final iconAsset = 'assets/images/img/$iconBase${isDark ? '-b' : ''}.png';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: dividerColor != null ? BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor, width: 0.5))) : null,
        child: Row(children: [
          Image.asset(iconAsset, width: 16.5, height: 16.5),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.cn(15, color: textColor))),
          Image.asset('assets/images/img/right-ico.png', width: 6.5, height: 12),
        ]),
      ),
    );
  }

  /// 检查更新 - 调用真实版本检查接口 (对齐 zdj handleCheckUpdate)
  Future<void> _handleCheckUpdate() async {
    // 轻量 loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    AppUpdateInfo? info;
    Object? error;
    try {
      info = await AppUpdateService.checkUpdate();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭 loading

    if (error != null || info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败，请稍后再试'), duration: Duration(seconds: 2)),
      );
      return;
    }

    if (info.hasUpdate) {
      await UpdatePopup.show(context, info);
    } else {
      final pkg = await PackageInfo.fromPlatform();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已是最新版本 v${pkg.version}'), duration: const Duration(seconds: 2)),
      );
    }
  }
}
