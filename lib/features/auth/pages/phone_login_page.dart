import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';

/// 手机号输入页 — 1:1 复刻 uni-app phone.vue
class PhoneLoginPage extends ConsumerStatefulWidget {
  const PhoneLoginPage({super.key});
  @override
  ConsumerState<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends ConsumerState<PhoneLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _captchaAnswerCtrl = TextEditingController();
  bool _loading = false;
  String? _phoneError;
  String? _captchaError;
  String? _captchaId;
  String _captchaQuestion = '';

  static final _phoneRegex = RegExp(r'^1[3-9]\d{9}$');

  @override
  void dispose() { _phoneCtrl.dispose(); _captchaAnswerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111315) : Colors.white;
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999);
    final formBg = isDark ? const Color(0xFF202125) : const Color(0xFFF8F8F8);
    final formBorder = isDark ? const Color(0xFF2B2D33) : Colors.transparent;
    final inputColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final placeholderColor = isDark ? const Color(0xFF6F7682) : const Color(0xFFc7c7c7);
    final areaColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF3e3e3e);
    final areaBorder = isDark ? const Color(0xFF2B2D33) : const Color(0xFFececec);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          CustomNavBar(title: '手机号登录', showBack: true, backgroundColor: bgColor,
            titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('手机号验证码登录', style: TextStyle(fontSize: 23, height: 1.25, color: textColor)),
                  const SizedBox(height: 25),

                  // 手机号输入表单
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: formBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: formBorder, width: 0.5),
                    ),
                    child: Row(children: [
                      // +86 区号
                      Container(
                        width: 50, height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(border: Border(right: BorderSide(color: areaBorder, width: 0.5))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('+86', style: TextStyle(fontSize: 20, color: areaColor, fontFamily: 'DIN')),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down, size: 14, color: subColor),
                        ]),
                      ),
                      Expanded(child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        style: TextStyle(fontSize: 17, color: inputColor, fontFamily: 'DIN'),
                        decoration: InputDecoration(
                          hintText: '请输入手机号',
                          hintStyle: TextStyle(fontSize: 17, color: placeholderColor, fontFamily: 'DIN'),
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        onChanged: (_) => setState(() => _phoneError = null),
                      )),
                    ]),
                  ),

                  // 错误提示
                  if (_phoneError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 95, top: 9),
                      child: Text(_phoneError!, style: const TextStyle(fontSize: 14, color: Color(0xFFff4e5f))),
                    ),

                  const SizedBox(height: 38),

                  // "下一步" 按钮
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE45667),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE45667).withAlpha(179),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const Text('发送中...', style: TextStyle(fontSize: 17))
                          : const Text('下一步', style: TextStyle(fontSize: 17)),
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

  Future<void> _handleNext() async {
    final phone = _phoneCtrl.text.trim();
    if (!_phoneRegex.hasMatch(phone)) {
      setState(() => _phoneError = '请输入正确手机号');
      return;
    }
    setState(() => _loading = true);
    try {
      final captcha = await ref.read(authProvider.notifier).generateCaptcha();
      if (captcha != null && mounted) {
        setState(() { _captchaId = captcha.id; _captchaQuestion = captcha.question; _loading = false; });
        _showCaptchaDialog();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showCaptchaDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202125) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('安全验证', style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))),
            const SizedBox(height: 6),
            Text('请输入正确答案后继续', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999))),
            const SizedBox(height: 17),
            Text(_captchaQuestion, style: const TextStyle(fontSize: 21, color: Color(0xFF333333), fontFamily: 'DIN')),
            const SizedBox(height: 14),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _captchaAnswerCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333), fontFamily: 'DIN'),
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  hintStyle: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF6F7682) : const Color(0xFFc7c7c7)),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_captchaError != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_captchaError!, style: const TextStyle(fontSize: 13, color: Color(0xFFff4e5f)))),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                onPressed: _refreshCaptcha,
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                  foregroundColor: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666),
                  shape: const StadiumBorder(), elevation: 0),
                child: const Text('换一题', style: TextStyle(fontSize: 14)),
              ))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                onPressed: _handleCaptchaConfirm,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white, shape: const StadiumBorder(), elevation: 0),
                child: const Text('确定', style: TextStyle(fontSize: 14)),
              ))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _refreshCaptcha() async {
    final captcha = await ref.read(authProvider.notifier).generateCaptcha();
    if (mounted) {
      if (captcha != null) {
        setState(() { _captchaId = captcha.id; _captchaQuestion = captcha.question; _captchaError = null; });
      } else {
        setState(() => _captchaError = '获取验证码失败');
      }
    }
  }

  Future<void> _handleCaptchaConfirm() async {
    final answer = _captchaAnswerCtrl.text.trim();
    if (answer.isEmpty) { setState(() => _captchaError = '请输入答案'); return; }
    final success = await ref.read(authProvider.notifier).sendSmsCode(_phoneCtrl.text.trim(), _captchaId ?? '', answer);
    if (mounted) {
      if (success) {
        Navigator.pop(context); // 关闭弹窗
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.push('/login/phone-code', extra: _phoneCtrl.text.trim());
        });
      } else {
        setState(() => _captchaError = '答案错误，请重试');
      }
    }
  }
}
