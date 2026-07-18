import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';

/// 行情页头部 — 1:1 复刻 zdj-v1 pages/market/index.vue 的 .page-header
///
/// 源码结构：.page-header (position: fixed, overflow: hidden) 内含
///   - .page-header 自身背景渐变：linear-gradient(180deg, #f9ecd6 0%, #f7e7cf 62%, rgba(241,241,243,.96) 100%)
///   - .hero-bg 高 420rpx(=210px，从页面顶算起，含状态栏)，径向高光 + 纵向渐变
///   - .header-inner padding: 顶部 statusBarHeight+14, 左右 24rpx(=12), 底 18rpx(=9)
/// 暗色：.page-header 背景 #111315；hero 为 8% 白 / 12% 红 的两处径向高光。

/// 头部总内容高度：14(上) + 40(搜索框 80rpx) + 9(下) = 63
const double kMarketHeaderContentHeight = 63;

/// 头部背景层 — 放在外层 Stack 中（SafeArea 之外），渐变延伸到状态栏后面。
class MarketHeaderBackground extends StatelessWidget {
  final bool isDark;
  final double topPad;
  const MarketHeaderBackground({super.key, required this.isDark, required this.topPad});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topPad + kMarketHeaderContentHeight,
      width: double.infinity,
      child: ClipRect(
        child: Stack(children: [
          // .page-header 背景渐变（暗色为纯 #111315）
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : null,
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF9ECD6), Color(0xFFF7E7CF), Color(0xF5F1F1F3)],
                        stops: [0.0, 0.62, 1.0],
                      ),
              ),
            ),
          ),
          // .hero-bg（高 420rpx=210，被 .page-header overflow:hidden 裁切）
          Positioned(
            top: 0, left: 0, right: 0, height: 210 + topPad,
            child: _HeroBg(isDark: isDark),
          ),
        ]),
      ),
    );
  }
}

class _HeroBg extends StatelessWidget {
  final bool isDark;
  const _HeroBg({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // 纵向基底渐变（暗色为纯 #111315）
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [AppColors.darkBg, AppColors.darkBg]
                : const [Color(0xFFF9ECD6), Color(0xFFF7E7CF), Color(0xFFF4F2EF)],
            stops: isDark ? null : const [0.0, 0.42, 1.0],
          ),
        ),
      ),
      // radial-gradient(circle at 20% 25%, 白高光, transparent 28%)
      Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.5), // 20% 25%
            radius: 0.7,
            colors: [
              Colors.white.withAlpha(isDark ? 20 : 153), // 0.08 / 0.6
              Colors.transparent,
            ],
          ),
        ),
      ),
      // radial-gradient(circle at 75% 18%, 暖色/红高光, transparent 38%)
      Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.5, -0.64), // 75% 18%
            radius: 0.9,
            colors: [
              isDark
                  ? const Color(0xFFE05665).withAlpha(31) // rgba(224,86,101,.12)
                  : const Color(0xFFFFE7CA).withAlpha(242), // rgba(255,231,202,.95)
              Colors.transparent,
            ],
          ),
        ),
      ),
    ]);
  }
}

/// 头部内容层 — 透明背景，放在 SafeArea 内的 Column 顶部。
/// paddingTop = 状态栏(SafeArea) + 14，对齐源码 statusBarHeight + 14。
class MarketHeaderContent extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSearch;
  const MarketHeaderContent({super.key, required this.isDark, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final mutedIcon = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7B7C81); // useAppTheme mutedIconColor
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 12, right: 12, bottom: 9),
      child: Row(children: [
        // .title-wrap（gap 10rpx=5）
        Image.asset('assets/images/img/jianbei.png', width: 18, height: 18),
        const SizedBox(width: 5),
        Text('行情榜单', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black)),
        const SizedBox(width: 10), // .topbar gap 20rpx=10
        // .search-box
        Expanded(
          child: GestureDetector(
            onTap: onSearch,
            child: Container(
              height: 40, // 80rpx
              padding: const EdgeInsets.symmetric(horizontal: 15), // 30rpx
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : Colors.white.withAlpha(240), // rgba(255,255,255,.94)
                borderRadius: BorderRadius.circular(24), // 48rpx
                boxShadow: isDark
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x14AD8955), // rgba(173,137,85,.08)
                          offset: Offset(0, 8), // 16rpx
                          blurRadius: 20, // 40rpx
                        ),
                      ],
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '输入名称编号',
                    style: AppTextStyles.cn(13,
                        color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFBBB2AA)),
                  ),
                ),
                const SizedBox(width: 8), // 16rpx
                Icon(AppIcons.search, size: 22, color: mutedIcon),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
