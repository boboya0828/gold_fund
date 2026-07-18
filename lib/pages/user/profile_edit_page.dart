import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/storage_service.dart';
import '../../features/auth/providers/theme_provider.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/profile_avatar_uploader.dart';

/// 个人资料页 — 1:1 复刻 uni-app pages/user/center/profile.vue
/// 头像（可更换）/ 昵称 / ID（点击复制）/ 皮肤切换 / 安全设置
///
/// 平台专有能力（umeng 埋点、相册权限说明弹窗）未迁移；
/// uni-app 的压缩逻辑映射为 image_picker 的 imageQuality: 60。
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  static const _maxAvatarSize = 10 * 1024 * 1024; // uni-app MAX_AVATAR_SIZE

  final ApiClient _api = ApiClient();
  final ProfileAvatarUploader _uploader = ProfileAvatarUploader();

  String _avatarUrl = '';
  String _nickname = '';
  String _userId = '';
  Uint8List? _localAvatarBytes; // 上传中本地预览（对齐 uni-app 乐观更新本地路径）
  bool _avatarUploading = false;
  bool _loadingShown = false;

  @override
  void initState() {
    super.initState();
    _loadCachedUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUserInfo());
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

  /// uni-app normalizeUserInfo
  static Map<String, dynamic> _normalizeUser(Map<String, dynamic> raw) {
    return <String, dynamic>{
      ...raw,
      'avatarUrl': raw['avatarUrl'] ?? raw['avatar'] ?? '',
      'nickname': raw['nickname'] ?? raw['userName'] ?? '',
      'userId': raw['userId'] ?? raw['id'] ?? '',
      'id': raw['id'] ?? raw['userId'] ?? '',
    };
  }

  /// uni-app: 页面打开时先读缓存 userInfo
  Future<void> _loadCachedUserInfo() async {
    final cached = await StorageService().userInfo;
    if (cached != null && mounted) _applyUserInfo(_normalizeUser(cached));
  }

  void _applyUserInfo(Map<String, dynamic> user) {
    setState(() {
      _avatarUrl = (user['avatarUrl'] ?? '').toString();
      _nickname = (user['nickname'] ?? '').toString();
      _userId = (user['userId'] ?? user['id'] ?? '').toString();
    });
  }

  /// uni-app refreshUserInfo（onShow 触发）
  Future<void> _refreshUserInfo() async {
    try {
      final res = await _api.get(ApiEndpoints.getCurrentUser);
      final normalized = _normalizeUser(_extractUser(res.data));
      await StorageService().setUserInfo(normalized);
      if (mounted) _applyUserInfo(normalized);
    } catch (_) {/* 静默处理 */}
  }

  /// uni-app uni.showLoading({ mask: true })
  void _showLoading(String title) {
    _loadingShown = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : const Color(0xFF333333),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => _loadingShown = false);
  }

  void _hideLoading() {
    if (_loadingShown && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// uni-app handleChangeAvatar：选图 → 大小校验 → 乐观预览 → 签名上传 → 回写
  Future<void> _handleChangeAvatar() async {
    if (_avatarUploading) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, // uni-app sourceType: ['album']
      imageQuality: 60, // 对齐 uni-app sizeType:['compressed'] + compressImage quality:60
    );
    if (picked == null) return;

    final size = await picked.length();
    if (size > _maxAvatarSize) {
      _toast('图片过大，请重新选择');
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _localAvatarBytes = bytes; // 乐观更新（对齐 uni-app userInfo.avatarUrl = uploadFilePath）
      _avatarUploading = true;
    });
    _showLoading('上传中...');
    try {
      await _uploader.uploadAvatar(picked);
      await _refreshUserInfo();
      if (!mounted) return;
      setState(() => _localAvatarBytes = null);
      _toast('头像更新成功');
    } catch (_) {
      // 失败回滚（对齐 uni-app userInfo.avatarUrl = previousAvatar）
      if (mounted) setState(() => _localAvatarBytes = null);
      _toast('头像上传失败');
    } finally {
      _hideLoading();
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  /// uni-app handleCopyId
  Future<void> _handleCopyId() async {
    await Clipboard.setData(ClipboardData(text: _userId));
    _toast('ID已复制');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.darkText : const Color(0xFF333333);
    final valueColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF999999);
    final themeMode = ref.watch(themeModeProvider);
    // uni-app skinLabelMap: light '白色皮肤' / dark '深色皮肤'，默认 light
    final skinLabel = themeMode == AppThemeMode.dark ? '深色皮肤' : '白色皮肤';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
      appBar: CustomNavBar(
        title: '个人资料',
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFFAF7F7),
        titleColor: labelColor,
      ),
      body: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10), // .page-content margin-top 20rpx
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
          children: [
            _row(
              label: '头像',
              isDark: isDark,
              labelColor: labelColor,
              trailing: _buildAvatar(isDark),
              onTap: _handleChangeAvatar,
            ),
            _divider(isDark),
            _row(
              label: '昵称',
              isDark: isDark,
              labelColor: labelColor,
              value: _nickname.isEmpty ? '未设置' : _nickname,
              valueColor: valueColor,
              onTap: () async {
                await context.push('/user/nickname');
                _refreshUserInfo(); // 对齐 uni-app onShow 刷新
              },
            ),
            _divider(isDark),
            _row(
              label: 'ID',
              isDark: isDark,
              labelColor: labelColor,
              value: _userId,
              valueColor: valueColor,
              onTap: _handleCopyId,
            ),
            _divider(isDark),
            _row(
              label: '皮肤切换',
              isDark: isDark,
              labelColor: labelColor,
              value: skinLabel,
              valueColor: valueColor,
              onTap: () => context.push('/user/skin'),
            ),
            _divider(isDark),
            _row(
              label: '安全设置',
              isDark: isDark,
              labelColor: labelColor,
              onTap: () => context.push('/user/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final Widget image;
    if (_localAvatarBytes != null) {
      image = Image.memory(_localAvatarBytes!, fit: BoxFit.cover);
    } else if (_avatarUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: _avatarUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Image.asset('assets/images/img/photo.png', fit: BoxFit.cover),
        errorWidget: (context, url, error) => Image.asset('assets/images/img/photo.png', fit: BoxFit.cover),
      );
    } else {
      // uni-app 默认头像 /static/image/img/photo.png
      image = Image.asset('assets/images/img/photo.png', fit: BoxFit.cover);
    }

    return Container(
      width: 44, // 88rpx
      height: 44,
      margin: const EdgeInsets.only(right: 6), // 12rpx
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4), // 8rpx
        color: isDark ? const Color(0xFF282828) : null,
        border: isDark ? Border.all(color: const Color(0xFF2B2D33), width: 0.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      // uni-app .avatar-img border-radius: 50% → 圆形头像
      child: ClipOval(child: image),
    );
  }

  Widget _row({
    required String label,
    required bool isDark,
    required Color labelColor,
    required VoidCallback onTap,
    String? value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50), // 100rpx
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // 10rpx 40rpx
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.cn(15, color: labelColor)), // 30rpx
            Row(
              children: [
                ?trailing,
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6), // 12rpx
                    child: Text(value, style: AppTextStyles.cn(14, color: valueColor)), // 28rpx
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 5), // 10rpx
                  child: Image.asset(
                    'assets/images/img/right-ico.png',
                    width: 6.5, // 13rpx
                    height: 12, // 24rpx
                    // 深色 filter: invert(1) opacity(0.62)
                    color: isDark ? const Color(0x9EFFFFFF) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      height: 0.5, // 1rpx
      margin: const EdgeInsets.symmetric(horizontal: 20), // 40rpx
      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFEF),
    );
  }
}
