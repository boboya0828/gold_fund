import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 密码登录页 — 1:1 复刻 uni-app password.vue
class PasswordLoginPage extends ConsumerStatefulWidget {
  const PasswordLoginPage({super.key});
  @override
  ConsumerState<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends ConsumerState<PasswordLoginPage> {
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _formError;

  @override
  void dispose() { _accountCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111315) : Colors.white;
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9a9a9a);
    final formBg = isDark ? const Color(0xFF202125) : const Color(0xFFF8F8F8);
    final formBorder = isDark ? const Color(0xFF2B2D33) : Colors.transparent;
    final inputColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final placeholderColor = isDark ? const Color(0xFF6F7682) : const Color(0xFFc7c7c7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          CustomNavBar(title: '密码登陆', showBack: true, backgroundColor: bgColor,
            titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('密码登陆', style: TextStyle(fontSize: 23, height: 1.25, color: textColor)),
                  const SizedBox(height: 9),
                  Text('请输入账号和密码登陆养基助手', style: TextStyle(fontSize: 15, color: subColor)),
                  const SizedBox(height: 25),

                  // 账号输入
                  _buildInput(placeholder: '请输入手机号/账号', controller: _accountCtrl,
                    formBg: formBg, formBorder: formBorder, inputColor: inputColor, placeholderColor: placeholderColor),
                  const SizedBox(height: 14),

                  // 密码输入 (带眼睛切换)
                  Container(
                    height: 46,
                    decoration: BoxDecoration(color: formBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: formBorder, width: 0.5)),
                    child: Row(children: [
                      Expanded(child: TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        style: TextStyle(fontSize: 17, color: inputColor),
                        decoration: InputDecoration(
                          hintText: '请输入密码',
                          hintStyle: TextStyle(fontSize: 17, color: placeholderColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                      )),
                      GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Container(
                          width: 44, height: 46,
                          alignment: Alignment.center,
                          child: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 22, color: subColor),
                        ),
                      ),
                    ]),
                  ),

                  // 错误提示
                  if (_formError != null)
                    Padding(padding: const EdgeInsets.only(top: 9), child: Text(_formError!, style: const TextStyle(fontSize: 14, color: Color(0xFFff4e5f)))),

                  const SizedBox(height: 38),

                  // 登录按钮
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withAlpha(179),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const Text('登录中...', style: TextStyle(fontSize: 17))
                          : const Text('登录', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInput({required String placeholder, required TextEditingController controller,
    required Color formBg, required Color formBorder, required Color inputColor, required Color placeholderColor}) {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: formBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: formBorder, width: 0.5)),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 17, color: inputColor),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 17, color: placeholderColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final account = _accountCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (account.isEmpty) { setState(() => _formError = '请输入手机号/账号'); return; }
    if (password.isEmpty) { setState(() => _formError = '请输入密码'); return; }
    setState(() { _loading = true; _formError = null; });
    final success = await ref.read(authProvider.notifier).passwordLogin(account, password);
    if (mounted) {
      setState(() => _loading = false);
      if (success) context.go('/home');
    }
  }
}
