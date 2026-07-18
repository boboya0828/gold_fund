import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 会员页头部 — 1:1 复刻 uni-app pages/member/index.vue 的
/// `.user-center`（用户卡） + `.vipmun`（VIP 菜单）负 margin 叠加结构。
///
/// uni-app 布局换算（rpx÷2）：
///   .user-center: margin-top 24rpx→12, height 278rpx→139, radius 14rpx→7,
///                 左右 margin 32rpx→16, padding-top 40rpx→20, 左右 padding 34rpx→17
///   .vipmun:      height 242rpx→121, margin-top -130rpx→-65, 全宽背景图
///   .massag:      margin-top -74rpx→-37（由调用方接续）
///   总高 = 12 + 139 - 65 + 121 - 37 = 170
class MemberVipHeader extends StatelessWidget {
  final String avatar;
  final String nickname;
  final bool isDark;

  /// VIP早报 → /member/morning-news
  final VoidCallback onMorningNews;

  /// 流入流出 → /member/contrast
  final VoidCallback onContrast;

  /// 关注度飙升 → /member/rising-chart
  final VoidCallback onRisingChart;

  /// 尾盘参考 → uni-app ./closingnews（Flutter 暂无对应路由）
  final VoidCallback onClosingNews;

  const MemberVipHeader({
    super.key,
    required this.avatar,
    required this.nickname,
    required this.isDark,
    required this.onMorningNews,
    required this.onContrast,
    required this.onRisingChart,
    required this.onClosingNews,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ===== 用户卡 .user-center =====
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              height: 139,
              decoration: BoxDecoration(
                // linear-gradient(134deg, #FFF2D6 0%, #FFDED5 100%)，明暗主题一致
                gradient: const LinearGradient(
                  begin: Alignment(-0.7, -1.0),
                  end: Alignment(0.7, 1.0),
                  colors: [Color(0xFFFFF2D6), Color(0xFFFFDED5)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.fromLTRB(17, 20, 17, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // .profile image: 100rpx→50 圆形，默认 photo.png
                  ClipOval(
                    child: avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatar,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade300),
                            errorWidget: (_, _, _) => Image.asset(
                                'assets/images/img/photo.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/img/photo.png',
                            width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12), // .profile margin-right 24rpx
                  // 昵称 + VIP 图标（uni-app 中到期日/续费入口均已注释，不渲染）
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        // .user-name: 32rpx→16, 恒为 #333333（渐变卡上不变色）
                        Text(nickname,
                            style: AppTextStyles.cn(16,
                                color: const Color(0xFF333333))),
                        const SizedBox(width: 14), // .vipico margin-left 28rpx
                        // .vipico image: 28x25rpx → 14x12.5
                        Image.asset('assets/images/img/vipico1.png',
                            width: 14, height: 12.5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ===== VIP 菜单 .vipmun =====
          Positioned(
            top: 86, // 12 + 139 - 65
            left: 0,
            right: 0,
            child: Container(
              height: 121,
              decoration: BoxDecoration(
                // vipMenuBg: 浅色 vipbg.png / 深色 vipbg-b.png，background-size 100% 100%
                image: DecorationImage(
                  image: AssetImage(isDark
                      ? 'assets/images/img/vipbg-b.png'
                      : 'assets/images/img/vipbg.png'),
                  fit: BoxFit.fill,
                ),
              ),
              child: Row(
                children: [
                  _menuItem('assets/images/img/vipzb.png', 'VIP早报', onMorningNews),
                  _menuItem('assets/images/img/viplc.png', '流入流出', onContrast),
                  _menuItem('assets/images/img/vipbs.png', '关注度飙升', onRisingChart),
                  _menuItem('assets/images/img/vipwp.png', '尾盘参考', onClosingNews),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// .vipmun-list: flex 1 居中；.munimag image 78rpx→39；.muntext 26rpx→13
  Widget _menuItem(String asset, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(asset, width: 39, height: 39),
            const SizedBox(height: 4),
            // 深色下 .muntext 强制 #D7DAE0
            Text(label,
                style: AppTextStyles.cn(13,
                    color: isDark ? const Color(0xFFD7DAE0) : null)),
          ],
        ),
      ),
    );
  }
}
