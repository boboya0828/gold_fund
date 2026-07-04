import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fund_group_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../../features/position/providers/position_provider.dart';

/// 顶部导航头 — 1:1 复刻 .pages-nav
class PositionNavHeader extends ConsumerWidget {
  final PositionState state;
  final bool isDark;
  final double topPadding;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final String backgroundAsset;
  final String fundGroupAsset;

  const PositionNavHeader({
    super.key,
    required this.state,
    required this.isDark,
    required this.topPadding,
    required this.onSearchTap,
    required this.onMenuTap,
    this.backgroundAsset = 'assets/images/img/position-bg.png',
    this.fundGroupAsset = 'assets/images/img/fundqun.png',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIconColor = isDark
        ? const Color(0xFFB7BBC4)
        : const Color(0xFF452008);

    return Container(
      // 源码 .pages-nav 浅色底 #F1F1F3（背景图之下的底色）
      // 注意：背景图已上移到 position_page.dart 页面级 Stack (延伸到状态栏后)，这里不再绘制。
      color: isDark ? const Color(0xFF202125) : const Color(0xFFF1F1F3),
      child: Stack(
        children: [
          // pages-nav padding: SafeArea 已消费状态栏，此处补 10px（对齐 topHeight=statusBarHeight+10）
          Padding(
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 5,
              left: 16,
              right: 16,
            ),
            child: Column(
              children: [
                // pagesnavtitle: margin-bottom: 20rpx = 10px
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 29, // 58rpx
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 基金群入口 — pagesnavtitle-l
                        GestureDetector(
                          onTap: () => FundGroupService.open(context),
                          child: Container(
                            width: 80,
                            height: 29,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.transparent : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              fundGroupAsset,
                              key: const Key('position-fund-group-image'),
                              width: 65,
                              height: 12.5,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                    '基金群',
                                    style: AppTextStyles.cn(
                                      12,
                                      color: isDark
                                          ? const Color(0xFFD6D8DE)
                                          : const Color(0xFF452008),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        // 标题
                        Text(
                          '养基助手',
                          style: AppTextStyles.cn(
                            16,
                            color: isDark
                                ? const Color(0xFFD6D8DE)
                                : const Color(0xFF452008),
                            weight: FontWeight.w700,
                          ),
                        ),
                        // 搜索+添加
                        Container(
                          width: 80,
                          height: 29,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.transparent : Colors.white,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: onSearchTap,
                                child: Icon(
                                  AppIcons.search,
                                  size: 20,
                                  color: navIconColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: onMenuTap,
                                child: Icon(
                                  AppIcons.add,
                                  size: 20,
                                  color: navIconColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ===== 账本标签 — pages-taber =====
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: state.bookNames.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () =>
                          ref.read(positionProvider.notifier).selectTab(i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 24), // 48rpx
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              state.bookNames[i],
                              style: AppTextStyles.cn(
                                15,
                                color: state.tabIndex == i
                                    ? (isDark
                                          ? Colors.white
                                          : const Color(0xFF452008))
                                    : (isDark
                                          ? const Color(0xFF777C86)
                                          : const Color(0xFF9A7A61)),
                                weight: state.tabIndex == i
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              key: Key('position-book-tab-indicator-$i'),
                              width: 27,
                              height: 4,
                              decoration: BoxDecoration(
                                color: state.tabIndex == i
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
