import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 绑定手机页 — 1:1 复刻 uni-app pages/user/center/boundphone.vue
/// 导航栏右侧保存按钮 + 手机号输入（^1\d{10}$ 校验）
class BoundPhonePage extends StatefulWidget {
  const BoundPhonePage({super.key});

  @override
  State<BoundPhonePage> createState() => _BoundPhonePageState();
}

class _BoundPhonePageState extends State<BoundPhonePage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _controller = TextEditingController();

  String _errorMsg = '';
  bool _isValid = false;

  static final _phoneReg = RegExp(r'^1\d{10}$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// uni-app: 兼容 {code,data} 包裹与直返两种结构
  static Map<String, dynamic> _extractUser(dynamic body) {
    if (body is! Map) return {};
    final inner = body['data'];
    final target = inner is Map ? inner : body;
    return target.cast<String, dynamic>();
  }

  /// uni-app onMounted: getCurrentUser → 预填手机号（预填不触发校验）
  Future<void> _prefill() async {
    try {
      final res = await _api.get(ApiEndpoints.getCurrentUser);
      final raw = _extractUser(res.data);
      final phone = (raw['phoneNumber'] ?? raw['phone'] ?? '').toString();
      if (mounted && phone.isNotEmpty) {
        _controller.text = phone;
      }
    } catch (_) {/* 静默处理 */}
  }

  /// uni-app validatePhoneNumber
  void _validate() {
    final val = _controller.text;
    String error = '';
    var valid = false;
    if (val.isEmpty) {
      // 空输入：无错误提示，仅置为无效
    } else if (!_phoneReg.hasMatch(val)) {
      error = '请输入正确手机号';
    } else {
      valid = true;
    }
    setState(() {
      _errorMsg = error;
      _isValid = valid;
    });
  }

  /// uni-app refreshUserInfo：保存后同步 userInfo 缓存
  Future<void> _refreshUserInfo() async {
    try {
      final res = await _api.get(ApiEndpoints.getCurrentUser);
      final raw = _extractUser(res.data);
      final normalized = <String, dynamic>{
        ...raw,
        'avatarUrl': raw['avatarUrl'] ?? raw['avatar'] ?? '',
        'nickname': raw['nickname'] ?? raw['userName'] ?? '',
        'userId': raw['userId'] ?? raw['id'] ?? '',
        'id': raw['id'] ?? raw['userId'] ?? '',
      };
      await StorageService().setUserInfo(normalized);
    } catch (_) {/* 静默处理 */}
  }

  /// uni-app handleSave：bindPhone(phoneNumber.trim()) — 源码直传字符串 body
  Future<void> _handleSave() async {
    _validate();
    if (!_isValid) {
      if (_controller.text.isEmpty) _toast('请输入手机号');
      return;
    }
    try {
      await _api.post(ApiEndpoints.bindPhone, data: _controller.text.trim());
      _toast('保存成功');
      await _refreshUserInfo();
      if (!mounted) return;
      // uni-app: setTimeout(() => uni.navigateBack(), 800)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && Navigator.of(context).canPop()) context.pop();
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['message']?.toString() ?? '') : '';
      _toast(msg.isNotEmpty ? msg : '保存失败');
    } catch (_) {
      _toast('保存失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final placeholderColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFBBBBBB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
      appBar: CustomNavBar(
        title: '绑定手机号',
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFFAF7F7),
        titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        rightWidget: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleSave,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '保存',
              style: AppTextStyles.cn(
                14, // 28rpx
                color: _isValid ? AppColors.upColor : const Color(0xFF999999),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10), // .page-content margin-top 20rpx
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), // 40rpx 40rpx 0
        decoration: isDark
            ? const BoxDecoration(color: AppColors.darkBg)
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAF7F7), Colors.white],
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10), // .input-section margin-top 20rpx
            // 输入行
            Padding(
              padding: const EdgeInsets.only(bottom: 10), // padding-bottom 20rpx
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true, // uni-app focus
                      keyboardType: TextInputType.number, // type="number"
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11), // maxlength 11
                      ],
                      style: AppTextStyles.cn(17, color: inputColor), // 34rpx
                      cursorColor: AppColors.upColor,
                      decoration: InputDecoration.collapsed(
                        hintText: '请输入手机号',
                        hintStyle: AppTextStyles.cn(17, color: placeholderColor),
                      ),
                      onChanged: (_) => _validate(),
                    ),
                  ),
                  if (_errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 10), // 20rpx
                      child: Text(
                        _errorMsg,
                        maxLines: 1,
                        softWrap: false,
                        style: AppTextStyles.cn(13, color: AppColors.upColor), // 26rpx
                      ),
                    ),
                ],
              ),
            ),
            // 分割线
            Container(
              height: 0.5, // 1rpx
              margin: const EdgeInsets.only(bottom: 12), // 24rpx
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFE2E2E2),
            ),
            // 提示
            Text(
              '请输入您的手机号',
              style: AppTextStyles.cn(
                12, // 24rpx
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFFBBBBBB),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
