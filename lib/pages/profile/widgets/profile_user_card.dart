import 'package:flutter/material.dart';

import '../../../core/models/user.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'dark_mode_icon.dart';

/// 我的页用户信息卡 - 1:1 复刻 uni-app pages/user/index.vue 的 .user 区块
///
/// 头像 104rpx=52 圆形（深色：2rpx=1 边框 #2B2D33 + 底色 #282828），无 avatarUrl 回退 photo.png；
/// 昵称 32rpx=16 加粗（昵称为空回退 username）；手机号 24rpx=12；
/// 未登录显示 38rpx=19「登录/注册」；右箭头 11x20rpx=5.5x10。
class ProfileUserCard extends StatelessWidget {
  final UserInfo? user;
  final bool isAuthenticated;
  final VoidCallback onTap;

  const ProfileUserCard({
    super.key,
    required this.user,
    required this.isAuthenticated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUser = isAuthenticated && user != null;
    final avatar = user?.avatarUrl ?? '';
    // vue: userInfo.nickname != '' ? userInfo.nickname : userInfo.username
    final displayName = (user?.nickname?.isNotEmpty ?? false) ? user!.nickname! : (user?.username ?? '');
    final phone = user?.phoneNumber ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          // .theme-dark .userimg image: 2rpx solid #2B2D33 + background #282828
          decoration: isDark
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emptyIconBgDark, // #282828
                  border: Border.all(color: AppColors.assetDividerDark, width: 1), // #2B2D33
                )
              : null,
          child: ClipOval(
            child: avatar.isNotEmpty
                ? Image.network(avatar, width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Image.asset('assets/images/img/photo.png', width: 52, height: 52, fit: BoxFit.cover))
                : Image.asset('assets/images/img/photo.png', width: 52, height: 52, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 15), // .userimg image margin-right 30rpx
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasUser) ...[
              Text(
                displayName,
                style: AppTextStyles.cn(16,
                    color: isDark ? AppColors.darkText : const Color(0xFF232323), weight: FontWeight.bold),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 7), // .font2 margin-top 14rpx
                Text(phone,
                    style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF868686))),
              ],
            ] else
              Text('登录/注册', style: AppTextStyles.cn(19, color: isDark ? AppColors.darkText : Colors.black)),
          ]),
        ),
        DarkModeIconFilter(
          isDark: isDark,
          child: Image.asset('assets/images/img/right-ico1.png', width: 5.5, height: 10),
        ),
      ]),
    );
  }
}
