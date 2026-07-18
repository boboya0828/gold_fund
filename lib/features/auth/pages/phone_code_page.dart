import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';

/// 验证码输入页 — 1:1 复刻 uni-app phone-code.vue
class PhoneCodePage extends ConsumerStatefulWidget {
  const PhoneCodePage({super.key});
  @override
  ConsumerState<PhoneCodePage> createState() => _PhoneCodePageState();
}

class _PhoneCodePageState extends ConsumerState<PhoneCodePage> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  int _countdown = 60;
  bool _loading = false;
  String? _captchaId;
  String _captchaQuestion = '';
  final _captchaAnswerCtrl = TextEditingController();
  String? _captchaError;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _focusNode.dispose(); _captchaAnswerCtrl.dispose(); _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) { t.cancel(); if (mounted) setState(() => _countdown = 0); }
      else { if (mounted) setState(() => _countdown--); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111315) : Colors.white;
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9b9b9b);
    final boxBg = isDark ? const Color(0xFF202125) : const Color(0xFFf7f7f7);
    final boxBorder = isDark ? const Color(0xFF2B2D33) : Colors.transparent;
    final boxText = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final resendColor = _countdown > 0
        ? (isDark ? const Color(0xFF5E6673) : const Color(0xFFa8b9e8))
        : (isDark ? const Color(0xFF8EAFFF) : const Color(0xFF2f78ff));
    final phone = (GoRouterState.of(context).extra as String?) ?? '17600000000';
    final maskedPhone = '${phone.substring(0, phone.length < 3 ? phone.length : 3)}****${phone.length > 7 ? phone.substring(7) : ''}';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          CustomNavBar(title: '请输入验证码', showBack: true, backgroundColor: bgColor,
            titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('请输入验证码', style: TextStyle(fontSize: 28, height: 1.3, color: textColor)),
                  const SizedBox(height: 8),
                  Text('验证码已发送到 $maskedPhone', style: TextStyle(fontSize: 14, color: subColor)),
                  const SizedBox(height: 37),

                  // 6个验证码格子
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        final digit = i < _codeCtrl.text.length ? _codeCtrl.text[i] : '';
                        return Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: boxBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: boxBorder, width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(digit, style: TextStyle(fontSize: 18, color: boxText, fontFamily: 'DIN')),
                        );
                      }),
                    ),
                  ),

                  // 隐藏输入框 (使用 Stack 嵌入以接收键盘输入)
                  SizedBox(
                    height: 0,
                    child: TextField(
                      controller: _codeCtrl,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 1, color: Colors.transparent),
                      decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                      onChanged: (v) {
                        setState(() {});
                        if (v.length == 6 && !_loading) _handleLogin();
                      },
                    ),
                  ),

                  const SizedBox(height: 13),

                  // 重新发送
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: (_countdown == 0 && !_loading) ? _handleResend : null,
                      child: Text(
                        _countdown > 0 ? '${_countdown}s后重新发送' : '重新发送验证码',
                        style: TextStyle(fontSize: 14, color: resendColor),
                      ),
                    ),
                  ),

                  if (_loading)
                    const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final phone = (GoRouterState.of(context).extra as String?) ?? '';
    setState(() => _loading = true);
    final success = await ref.read(authProvider.notifier).phoneLogin(phone, _codeCtrl.text);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功'), duration: Duration(milliseconds: 1500)),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/home');
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authProvider).error ?? '登录失败，请重试'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _handleResend() async {
    final captcha = await ref.read(authProvider.notifier).generateCaptcha();
    if (captcha != null && mounted) {
      setState(() { _captchaId = captcha.id; _captchaQuestion = captcha.question; });
      _showCaptchaDialog();
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
          decoration: BoxDecoration(color: isDark ? const Color(0xFF202125) : Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('安全验证', style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))),
            const SizedBox(height: 6),
            Text('请输入正确答案后继续', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999))),
            const SizedBox(height: 17),
            Text(_captchaQuestion, style: const TextStyle(fontSize: 21, fontFamily: 'DIN')),
            const SizedBox(height: 14),
            Container(
              height: 44,
              decoration: BoxDecoration(color: isDark ? const Color(0xFF282828) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: _captchaAnswerCtrl,
                keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontFamily: 'DIN'),
                decoration: const InputDecoration(hintText: '请输入答案', hintStyle: TextStyle(fontSize: 16, color: Color(0xFFc7c7c7)), border: InputBorder.none),
              ),
            ),
            if (_captchaError != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_captchaError!, style: const TextStyle(fontSize: 13, color: Color(0xFFff4e5f)))),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                onPressed: () async {
                  final captcha = await ref.read(authProvider.notifier).generateCaptcha();
                  if (mounted) {
                    if (captcha != null) {
                      setState(() { _captchaId = captcha.id; _captchaQuestion = captcha.question; _captchaError = null; });
                    } else {
                      setState(() => _captchaError = '获取验证码失败');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                  foregroundColor: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666), shape: const StadiumBorder(), elevation: 0),
                child: const Text('换一题', style: TextStyle(fontSize: 14)),
              ))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                onPressed: () async {
                  final answer = _captchaAnswerCtrl.text.trim();
                  if (answer.isEmpty) { setState(() => _captchaError = '请输入答案'); return; }
                  final phone = (GoRouterState.of(context).extra as String?) ?? '';
                  final success = await ref.read(authProvider.notifier).sendSmsCode(phone, _captchaId ?? '', answer);
                  if (mounted) {
                    if (success) {
                      Navigator.pop(ctx);
                      _startCountdown();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('验证码已发送'), duration: Duration(seconds: 1)),
                      );
                    } else {
                      setState(() => _captchaError = '答案错误，请重试');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: const StadiumBorder(), elevation: 0),
                child: const Text('确定', style: TextStyle(fontSize: 14)),
              ))),
            ]),
          ]),
        ),
      ),
    );
  }
}

