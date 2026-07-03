import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/app_update_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/theme_provider.dart';
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
  String _avatar = '';
  String _nickname = '';
  String _phone = '';
  bool _hasUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    SharedPreferences.getInstance().then((p) {
      final token = p.getString('token');
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _hasUser = false);
        return;
      }
      final raw = p.getString('userInfo');
      if (raw != null && raw.isNotEmpty) {
        try {
          // userInfo may be stored as JSON string or already parsed
          Map<String, dynamic> userData;
          if (raw.startsWith('{')) {
            try {
              userData = Map<String, dynamic>.from(
                const JsonDecoder().convert(raw) as Map);
            } catch (_) {
              userData = {};
            }
          } else {
            userData = {};
          }
          if (mounted) setState(() {
            _hasUser = true;
            _nickname = (userData['nickname'] ?? userData['nickName'] ?? userData['userName'] ?? userData['username'] ?? '用户') as String;
            _avatar = (userData['avatarUrl'] ?? userData['avatar'] ?? userData['headimgurl'] ?? '') as String;
            _phone = (userData['phoneNumber'] ?? userData['phone'] ?? userData['mobile'] ?? '') as String;
          });
        } catch (_) {
          if (mounted) setState(() => _hasUser = false);
        }
      } else {
        // Has token but no userInfo - may have been stored directly
        if (mounted) setState(() { _hasUser = true; _nickname = '用户'; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
                    // Avatar
                    Container(
                      width: 52, height: 52,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.grey.shade300,
                        image: _avatar.isNotEmpty ? DecorationImage(image: NetworkImage(_avatar), fit: BoxFit.cover) : null,
                      ),
                      child: _avatar.isEmpty ? Icon(Icons.person, size: 28, color: Colors.grey.shade400) : null,
                    ),
                    // Name + phone
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_hasUser) ...[
                          Text(_nickname.isNotEmpty ? _nickname : '用户', style: AppTextStyles.cn(16, color: const Color(0xFF232323), weight: FontWeight.bold)),
                          if (_phone.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(_phone, style: AppTextStyles.cn(12, color: const Color(0xFF868686))),
                          ],
                        ] else
                          Text('登录/注册', style: AppTextStyles.cn(19, color: textColor)),
                      ]),
                    ),
                    Image.asset('assets/images/img/leftico.png', width: 5.5, height: 10),
                  ]),
                ),
              ),
              const SizedBox(height: 21),
              // ===== 盈亏分析 =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(5)),
                child: _menuRow('assets/images/img/uico7.png', '盈亏分析', dividerColor, isDark, () {
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
                  _menuRowNet('uico4', '分享App', dividerColor, isDark, () => context.push('/user/share')),
                  _menuRowNet('uico5', '隐私政策', dividerColor, isDark, () => context.push('/privacy')),
                  _menuRowNet('uico1', '用户协议', dividerColor, isDark, () => context.push('/agreement')),
                  _menuRowNet('uico6', '检查更新', null, isDark, _handleCheckUpdate),
                ]),
              ),
              const SizedBox(height: 16),
              // ===== 深色模式 =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: Text('深色模式', style: AppTextStyles.cn(15, color: textColor)),
                  secondary: Icon(Icons.dark_mode_outlined, size: 22, color: subColor),
                  value: isDark,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                  activeTrackColor: AppColors.primary,
                ),
              ),
              // ===== 退出登录 =====
              if (_hasUser) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.upColor, padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: surfaceColor,
                    ),
                    child: const Text('退出登录', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _menuRow(String assetIcon, String label, Color? dividerColor, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: dividerColor != null ? BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor, width: 0.5))) : null,
        child: Row(children: [
          Image.asset(assetIcon, width: 16.5, height: 16.5),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : Colors.black87))),
          Image.asset('assets/images/img/leftico.png', width: 6.5, height: 12),
        ]),
      ),
    );
  }

  /// 功能菜单行 - iconBase 为图标基名 (如 uico4)，深色模式加载 -b 变体 (对齐 zdj getUserIcon)
  Widget _menuRowNet(String iconBase, String label, Color? dividerColor, bool isDark, VoidCallback onTap) {
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final iconUrl = 'https://huangjinetf.com/wxapp/image/img/$iconBase${isDark ? '-b' : ''}.png';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: dividerColor != null ? BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor, width: 0.5))) : null,
        child: Row(children: [
          Image.network(iconUrl, width: 16.5, height: 16.5, errorBuilder: (_, __, ___) => Icon(Icons.help_outline, size: 16.5, color: textColor)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.cn(15, color: textColor))),
          Image.asset('assets/images/img/leftico.png', width: 6.5, height: 12),
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
