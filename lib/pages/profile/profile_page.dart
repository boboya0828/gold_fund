import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/app_update_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/widgets/update_popup.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/profile_menu_row.dart';
import 'widgets/profile_user_card.dart';

/// 我的页面 - 1:1 复刻 uni-app pages/user/index.vue (基准: zdj-v1)
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// 对齐 vue isCheckingAppUpdate，防止重复点击发起多次版本检查
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .bg background-color: #F1F1F3；.theme-dark → #111315 (DARK_PAGE_BACKGROUND)
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);
    // .box-grid/.box3 background: #fff；.theme-dark → #202125
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(children: [
            // .bg background-image: position-bg.png，background-size: 100% 470rpx(=235)，
            // 深色模式 background-image: none
            if (!isDark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 235,
                child: Image.asset('assets/images/img/position-bg.png', fit: BoxFit.fill),
              ),
            Column(children: [
              // .title marginTop = statusBarHeight + 10（SafeArea 已提供 statusBarHeight）
              Container(
                margin: const EdgeInsets.only(top: 10),
                alignment: Alignment.center,
                // 浅色模式 .title 未指定颜色，继承 webview 默认黑色；.theme-dark .title → #D7DAE0
                child: Text('我的', style: AppTextStyles.cn(18, color: isDark ? AppColors.darkText : Colors.black)),
              ),
              const SizedBox(height: 25), // .user margin-top 50rpx
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18), // .user margin 36rpx
                child: ProfileUserCard(
                  user: authState.user,
                  isAuthenticated: authState.isAuthenticated,
                  // navTo('/pages/user/center/profile', 1)
                  onTap: () => _navWithLoginGuard('/user/profile'),
                ),
              ),
              const SizedBox(height: 16), // .box-grid mt-4 = 1rem = 16
              _menuBox(surfaceColor, [
                // box-grid 内唯一菜单行 = .list2:last-child → 无分隔线
                ProfileMenuRow(
                  iconBase: 'uico7',
                  label: '盈亏分析',
                  showDivider: false,
                  // navTo('/pages/user/curve', 1)
                  onTap: () => _navWithLoginGuard('/user/curve'),
                ),
              ]),
              const SizedBox(height: 12), // .box3 margin-top 24rpx
              _menuBox(surfaceColor, [
                // 意见反馈/安全设置：zdj-v1 源码中已注释停用，不展示
                ProfileMenuRow(iconBase: 'uico4', label: '分享App', onTap: () => context.push('/user/share')),
                ProfileMenuRow(iconBase: 'uico5', label: '隐私政策', onTap: () => context.push('/privacy')),
                ProfileMenuRow(iconBase: 'uico1', label: '用户协议', onTap: () => context.push('/agreement')),
                ProfileMenuRow(iconBase: 'uico6', label: '检查更新', showDivider: false, onTap: _handleCheckUpdate),
              ]),
              const SizedBox(height: 66), // .box3 mb-4 (16) + .bg padding-bottom 100rpx (50)
            ]),
          ]),
        ),
      ),
    );
  }

  /// 白底圆角菜单盒 - .box-grid/.box3（mr-4/ml-4 = 1rem = 16，border-radius 10rpx = 5）
  Widget _menuBox(Color color, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Column(children: rows),
    );
  }

  /// navTo(url, 1)：目标页需要登录；未登录跳登录页
  /// （vue: /pages/login/wxLogin?redirect=user，登录成功返回「我的」tab；
  ///   Flutter 登录页为 push/pop，成功后回到本 tab，语义一致）
  void _navWithLoginGuard(String route) {
    if (!ref.read(authProvider).isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push(route);
  }

  /// 检查更新 - 对齐 vue handleCheckUpdate / checkAppUpdate（含 withTimeout 8s 超时）
  Future<void> _handleCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // uni.showLoading({ title: '检查中...', mask: true })
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 12),
              Text('检查中...', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : AppColors.lightText)),
            ]),
          ),
        ),
      ),
    );

    AppUpdateInfo? info;
    Object? error;
    try {
      info = await AppUpdateService.checkUpdate().timeout(const Duration(seconds: 8));
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // uni.hideLoading()
    setState(() => _checkingUpdate = false);

    if (error != null || info == null) {
      // uni.showToast({ title: error?.message || '检查更新失败', icon: 'none' })
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败'), duration: Duration(seconds: 2)),
      );
      return;
    }

    if (info.hasUpdate) {
      await UpdatePopup.show(context, info);
      return;
    }

    // uni.showModal({ title: '当前版本', content: '已是最新版本 vX.Y（N）', showCancel: false })
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final versionName = pkg.version.replaceFirst(RegExp('^v', caseSensitive: false), '');
    final versionCode = int.tryParse(pkg.buildNumber) ?? 0;
    final versionText =
        versionName.isNotEmpty ? 'v$versionName${versionCode > 0 ? '（$versionCode）' : ''}' : '当前版本';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('当前版本'),
        content: Text('已是最新版本 $versionText'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('确定')),
        ],
      ),
    );
  }
}
