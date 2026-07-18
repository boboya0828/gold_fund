import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 隐私授权页 — 1:1 复刻 uni-app pages/common/privacy-auth.vue
///
/// 启动流程（对齐 onLoad → prepareLaunchPage）：
///   已授权 → 按 hasSeenGuide 直接进入 引导页/首页；未授权 → 弹出隐私授权弹窗。
/// 存储 key 与 uni-app utils/privacy.js 保持一致：
///   APP_PRIVACY_ACCEPTED / UMENG_PRIVACY_ACCEPTED / hasSeenGuide
///
/// 平台专有能力（未实现）：
///   - uni-app 原生隐私合规 API / 友盟 umeng 初始化（initUmengIfPrivacyAccepted）
///   - plus.navigator.closeSplashscreen 关闭原生启动屏
///   - uni.preloadPage 预加载 Tab 页
class PrivacyAuthPage extends StatefulWidget {
  const PrivacyAuthPage({super.key});

  @override
  State<PrivacyAuthPage> createState() => _PrivacyAuthPageState();
}

class _PrivacyAuthPageState extends State<PrivacyAuthPage>
    with WidgetsBindingObserver {
  bool _showSecondConfirm = false;
  bool _showPrivacyDialog = false;
  bool _exiting = false;

  late final TapGestureRecognizer _agreementRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  // 与 uni-app 保持一致的存储 key
  static const _umengPrivacyKey = 'UMENG_PRIVACY_ACCEPTED';
  static const _seenGuideKey = 'hasSeenGuide';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agreementRecognizer = TapGestureRecognizer()..onTap = _openAgreement;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
    // 对齐 onLoad → prepareLaunchPage
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareLaunchPage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _agreementRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  /// 对齐 onShow：从协议页返回 / 退出失败回到前台时恢复弹窗
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recoverPrivacyDialog();
  }

  // ===== 授权流程（对齐 utils/privacy.js）=====

  Future<bool> _hasAcceptedPrivacy() async {
    if (await StorageService().hasAcceptedPrivacy) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_umengPrivacyKey) ?? false;
  }

  Future<void> _markPrivacyAccepted() async {
    await StorageService().setPrivacyAccepted();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_umengPrivacyKey, true);
  }

  Future<void> _prepareLaunchPage() async {
    if (await _hasAcceptedPrivacy()) {
      await _goAfterAccepted();
      return;
    }
    if (mounted) setState(() => _showPrivacyDialog = true);
  }

  Future<void> _goAfterAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool(_seenGuideKey) ?? false;
    if (!mounted) return;
    if (!hasSeenGuide) {
      context.go('/guide'); // uni.reLaunch → /pages/guide/index
    } else {
      context.go('/home'); // uni.switchTab → /pages/index/index
    }
  }

  Future<void> _acceptPrivacy() async {
    await _markPrivacyAccepted();
    await _goAfterAccepted();
  }

  /// 对齐 onBackPress → refusePrivacy：返回键等同点击"不同意"
  void _refusePrivacy() {
    if (!_showSecondConfirm) {
      setState(() => _showSecondConfirm = true);
      return;
    }
    _exitApp();
  }

  Future<void> _exitApp() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    // 对齐 plus.runtime.quit / uni.exit 的最接近行为：
    // Android 退到后台；iOS 不支持主动退出，1200ms 后恢复弹窗
    await SystemNavigator.pop();
    _resetExitStateLater();
  }

  void _resetExitStateLater() {
    Timer(const Duration(milliseconds: 1200), _recoverPrivacyDialog);
  }

  Future<void> _recoverPrivacyDialog() async {
    if (await _hasAcceptedPrivacy()) return;
    if (!mounted) return;
    setState(() {
      _exiting = false;
      _showPrivacyDialog = true;
    });
  }

  void _openAgreement() => context.push('/agreement'); // pages/user/center/agreement
  void _openPrivacy() => context.push('/privacy'); // pages/user/center/privacy

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _refusePrivacy();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            // linear-gradient(164deg, #fff1ed 0%, #ffffff 100%)
            gradient: LinearGradient(
              begin: const Alignment(-0.28, -0.96),
              end: const Alignment(0.28, 0.96),
              colors: isDark
                  ? const [Color(0xFF241A1C), AppColors.darkBg]
                  : const [Color(0xFFFFF1ED), Color(0xFFFFFFFF)],
            ),
          ),
          child: Stack(children: [
            _buildBrand(isDark),
            if (_showPrivacyDialog) _buildMask(isDark),
          ]),
        ),
      ),
    );
  }

  /// 品牌区：top 34% + translateY(-50%) → 中心位于页面高度 34% 处
  Widget _buildBrand(bool isDark) {
    final titleColor =
        isDark ? const Color(0xFFD88E67) : const Color(0xFFB35A32);
    final subtitleColor =
        isDark ? const Color(0xFFB08B78) : const Color(0xFF9A6148);

    return Align(
      alignment: const Alignment(0, -0.32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Opacity(
          opacity: 0.9,
          child: Image.asset(
            'assets/images/img/u-logo.png',
            width: 90, // 180rpx
            height: 90,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 19), // 38rpx
        Text(
          '养基助手',
          style: AppTextStyles.cn(30, // 60rpx
                  color: titleColor, weight: FontWeight.w700)
              .copyWith(letterSpacing: 2), // 4rpx
        ),
        const SizedBox(height: 12), // 24rpx
        Text(
          '专业的基金/黄金白银一体化记账软件',
          style: AppTextStyles.cn(13, color: subtitleColor), // 26rpx
        ),
      ]),
    );
  }

  Widget _buildMask(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final primaryText = isDark ? AppColors.darkText : const Color(0xFF222224);
    final linkColor =
        isDark ? const Color(0xFF8FA2FF) : const Color(0xFF1F35B8);
    final refuseColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF8D8E92);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(148), // rgba(0,0,0,0.58)
        padding: const EdgeInsets.symmetric(horizontal: 21), // 42rpx
        child: Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 17), // 52/44/34rpx
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(9), // 18rpx
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _showSecondConfirm ? '确认提示' : '用户协议和隐私政策',
                style: AppTextStyles.cn(19, // 38rpx
                    color: primaryText, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 19), // 38rpx
              _buildContent(primaryText, linkColor),
              const SizedBox(height: 22), // 44rpx
              _buildActionButton(
                label: _showSecondConfirm ? '同意并继续' : '同意并接受',
                color: primaryText,
                weight: FontWeight.w500,
                onTap: _acceptPrivacy,
              ),
              const SizedBox(height: 10), // 20rpx
              _buildActionButton(
                label: _showSecondConfirm ? '退出应用' : '不同意',
                color: refuseColor,
                onTap: _refusePrivacy,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor, Color linkColor) {
    final base = AppTextStyles.cn(15.5, color: textColor, height: 1.45); // 31rpx
    final link = base.copyWith(color: linkColor);

    return Text.rich(
      _showSecondConfirm
          ? TextSpan(style: base, children: [
              const TextSpan(text: '进入应用前，你需要先同意'),
              TextSpan(
                  text: '《用户协议》', style: link, recognizer: _agreementRecognizer),
              const TextSpan(text: '和'),
              TextSpan(
                  text: '《隐私政策》', style: link, recognizer: _privacyRecognizer),
              const TextSpan(text: '，否则将无法继续使用应用。'),
            ])
          : TextSpan(style: base, children: [
              const TextSpan(
                  text: '请你务必审慎阅读、充分理解“用户协议”和“隐私政策”各条款，包括但不限于：为了更好地向你提供服务，我们需要收集你的设备标识、操作日志等信息用于分析、优化应用性能。'),
              const TextSpan(text: '你可阅读'),
              TextSpan(
                  text: '《用户协议》', style: link, recognizer: _agreementRecognizer),
              const TextSpan(text: '和'),
              TextSpan(
                  text: '《隐私政策》', style: link, recognizer: _privacyRecognizer),
              const TextSpan(text: '了解详细信息。如果你同意，请点击下面按钮开始接受我们的服务。'),
            ]),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    FontWeight? weight,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 46, // 92rpx
        alignment: Alignment.center,
        child: Text(label,
            style: AppTextStyles.cn(16, color: color, weight: weight)), // 32rpx
      ),
    );
  }
}
