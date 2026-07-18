import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 微信登录页 — 1:1 复刻 uni-app wxLogin.vue
class WxLoginPage extends ConsumerStatefulWidget {
  const WxLoginPage({super.key});
  @override
  ConsumerState<WxLoginPage> createState() => _WxLoginPageState();
}

class _WxLoginPageState extends ConsumerState<WxLoginPage> {
  bool _agreed = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white, // wxLogin 始终白色
      body: SafeArea(
        child: Column(children: [
          const CustomNavBar(title: '登录', showBack: true, backgroundColor: Colors.white, titleColor: Color(0xFF333333)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: Column(children: [
                // 标题
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Column(children: [
                    Text('登录 养基助手', style: AppTextStyles.cn(24, color: const Color(0xFF333333), weight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('首次登录成功后将自动完成注册', style: AppTextStyles.cn(13, color: const Color(0xFF969696))),
                  ]),
                ),
                const SizedBox(height: 50),

                // 微信登录按钮
                _buildWechatButton(authState.isLoading),
                const SizedBox(height: 18),

                // 手机号登录 (outline)
                SizedBox(
                  width: double.infinity, height: 44,
                  child: OutlinedButton(
                    onPressed: _loading ? null : () {
                      if (_ensureAgreementAccepted()) context.push('/login/phone');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text('手机号登录', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 15),

                // 协议复选框
                _buildAgreement(),
                const SizedBox(height: 42),

                // 其他方式登录
                _buildMoreLogin(),

                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(authState.error!, style: const TextStyle(fontSize: 14, color: Color(0xFFff4e5f))),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildWechatButton(bool loading) {
    return SizedBox(
      width: double.infinity, height: 45,
      child: ElevatedButton(
        onPressed: loading ? null : () {
          if (_ensureAgreementAccepted()) _handleWechatLogin();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(179),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.5)),
          elevation: 0,
        ),
        child: loading
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 8),
                Text('登录中...', style: TextStyle(fontSize: 16)),
              ])
            : const Text('微信登录', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildAgreement() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 21, height: 21,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _agreed ? AppColors.primary : Colors.transparent,
            border: Border.all(color: _agreed ? AppColors.primary : const Color(0xFFCCCCCC), width: 1.5),
          ),
          child: _agreed ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
        ),
        const SizedBox(width: 6),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            children: [
              TextSpan(text: '同意'),
              TextSpan(text: '《用户协议》', style: TextStyle(color: Color(0xFFE05665))),
              TextSpan(text: '与'),
              TextSpan(text: '《隐私条款》', style: TextStyle(color: Color(0xFFE05665))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildMoreLogin() {
    return GestureDetector(
      onTap: () {
        if (_ensureAgreementAccepted()) _showOtherLoginSheet();
      },
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11),
          child: Text('其他方式登录', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
      ]),
    );
  }

  void _showOtherLoginSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('其他方式登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, size: 22, color: Color(0xFF999999))),
              ]),
            ),
            // 账号密码登录
            GestureDetector(
              onTap: () { Navigator.pop(ctx); context.push('/login/password'); },
              child: Container(
                width: double.infinity, height: 48,
                margin: const EdgeInsets.only(bottom: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(24)),
                child: const Text('账号密码登录', style: TextStyle(fontSize: 15, color: Color(0xFF333333))),
              ),
            ),
            // 取消
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity, height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 15, color: Color(0xFF999999))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 对齐 zdj wxLogin.vue ensureAgreementAccepted：未勾选协议时弹 toast 并阻止后续操作
  bool _ensureAgreementAccepted() {
    if (_agreed) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先同意用户协议与隐私条款'), duration: Duration(seconds: 2)),
    );
    return false;
  }

  Future<void> _handleWechatLogin() async {
    setState(() => _loading = true);
    // TODO: 接入 fluwx SDK
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('微信SDK需要真机环境')));
    }
  }
}
