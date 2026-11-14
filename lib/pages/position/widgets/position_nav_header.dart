import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fund_group_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../../features/position/providers/position_provider.dart';
import '../../../core/utils/screen_adapt.dart';

/// 顶部导航头 — 1:1 复刻 .pages-nav
/// 标题栏（基金群胶囊 + 标题 + 搜索/添加）+ 账本 tab 行
/// （固定「账户汇总」+ 横滚账本 tab 列表 + 末尾「+」账本管理入口）
class PositionNavHeader extends ConsumerWidget {
  final PositionState state;
  final bool isDark;
  final double topPadding;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;

  /// 「+」按钮 → 账本管理页 (1:1 uni-app goLedgerPage → /pages/position/ledger)
  final VoidCallback? onAddTap;
  final String backgroundAsset;
  final String fundGroupAsset;

  const PositionNavHeader({
    super.key,
    required this.state,
    required this.isDark,
    required this.topPadding,
    required this.onSearchTap,
    required this.onMenuTap,
    this.onAddTap,
    this.backgroundAsset = 'assets/images/img/position-bg.png',
    this.fundGroupAsset = 'assets/images/img/fundqun.png',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIconColor = isDark
        ? const Color(0xFFB7BBC4)
        : const Color(0xFF452008);

    return Container(
      // 注意：背景图已上移到 position_page.dart 页面级 Stack (延伸到状态栏后)。
      // 浅色模式下这里必须透明，否则实色会盖住下层的背景图（暗色模式无背景图，用实色兜底）。
      color: isDark ? const Color(0xFF202125) : Colors.transparent,
      // pages-nav padding: SafeArea 已消费状态栏，此处补 10px（对齐 topHeight=statusBarHeight+10）
      child: Padding(
        padding: EdgeInsets.only(
          top: 10.sx,
          bottom: 5.sx,
          left: 16.sx,
          right: 16.sx,
        ),
        child: Column(
          children: [
            // pagesnavtitle: margin-bottom: 20rpx = 10px
            Padding(
              padding: EdgeInsets.only(bottom: 10.sx),
              child: SizedBox(
                height: 29.sx, // 58rpx
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 基金群入口 — pagesnavtitle-l（胶囊内纵向：图片 + 计数文字）
                    GestureDetector(
                      onTap: () => FundGroupService.open(context),
                      child: Container(
                        width: 80.sx, // 160rpx
                        height: 29.sx, // 58rpx
                        decoration: BoxDecoration(
                          color: isDark ? Colors.transparent : Colors.white,
                          borderRadius: BorderRadius.circular(25.sx), // 50rpx
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              fundGroupAsset,
                              key: const Key('position-fund-group-image'),
                              width: 54.sx, // 108rpx
                              height: 11.sx, // 22rpx
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                    '基金群',
                                    style: AppTextStyles.cn(
                                      12.sx,
                                      color: isDark
                                          ? const Color(0xFFD6D8DE)
                                          : const Color(0xFF452008),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 1.5), // gap 6rpx≈3，压缩到可用空间
                            Text(
                              state.fundGroupCountText,
                              key: const Key('position-fund-group-count'),
                              style: AppTextStyles.cn(
                                8.sx, // 16rpx
                                color: isDark
                                    ? const Color(0xFFA7ADB8)
                                    : const Color(0xFF9A7A61),
                                height: 1.25, // line-height 20rpx
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 标题
                    Text(
                      '养基助手',
                      style: AppTextStyles.cn(
                        17.sx, // 34rpx
                        color: isDark
                            ? const Color(0xFFD6D8DE)
                            : const Color(0xFF452008),
                      ),
                    ),
                    // 搜索+添加
                    Container(
                      width: 80.sx,
                      height: 29.sx,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.transparent : Colors.white,
                        borderRadius: BorderRadius.circular(25.sx),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: onSearchTap,
                            child: Icon(
                              AppIcons.search,
                              size: 20.sx,
                              color: navIconColor,
                            ),
                          ),
                          SizedBox(width: 16.sx), // margin-left 32rpx
                          GestureDetector(
                            onTap: onMenuTap,
                            child: Icon(
                              AppIcons.add,
                              size: 20.sx,
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
            // ===== 账本标签行 — pages-taber =====
            // 左固定「账户汇总」+ 右侧横滚 taberList + 末尾「+」账本管理
            SizedBox(
              height: 38.sx,
              child: Row(
                children: [
                  _tabItem(
                    label: '账户汇总',
                    active: state.isOverviewTab,
                    indicatorKey: const Key('position-book-tab-indicator-overview'),
                    onTap: () => ref
                        .read(positionProvider.notifier)
                        .selectTab(state.overviewTabIndex),
                  ),
                  SizedBox(width: 15.sx), // pages-taber gap 30rpx
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < state.bookNames.length; i++)
                          _tabItem(
                            label: state.bookNames[i],
                            active: state.tabIndex == i,
                            indicatorKey: Key('position-book-tab-indicator-$i'),
                            onTap: () => ref
                                .read(positionProvider.notifier)
                                .selectTab(i),
                          ),
                        // 「+」账本管理入口 — taber-item--add
                        GestureDetector(
                          key: const Key('position-book-tab-add'),
                          onTap: onAddTap,
                          child: Container(
                            padding: EdgeInsets.only(
                              top: 4.sx,
                              bottom: 9.sx,
                              left: 2.sx, // margin-left 4rpx
                            ),
                            color: Colors.transparent,
                            child: Icon(
                              Icons.add,
                              size: 18.sx,
                              color: Color(0xFF9A7A61),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个 tab — 1:1 .taber-item
  /// 未选 30rpx #9A7A61（深 #777C86）；选中 34rpx 700 #452008（深 #FFFFFF）
  /// 选中指示条 54x8rpx 圆角999 #E15665（深 #E05665），居中 bottom:0
  Widget _tabItem({
    required String label,
    required bool active,
    required Key indicatorKey,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 15.sx), // margin-right 30rpx
        padding: EdgeInsets.only(top: 4.sx, bottom: 9.sx), // padding 8rpx 0 18rpx
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.cn(
                active ? 17 : 15, // 34rpx / 30rpx
                color: active
                    ? (isDark ? Colors.white : const Color(0xFF452008))
                    : (isDark
                        ? const Color(0xFF777C86)
                        : const Color(0xFF9A7A61)),
                weight: active ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
            Container(
              key: indicatorKey,
              width: 27.sx, // 54rpx
              height: 4.sx, // 8rpx
              decoration: BoxDecoration(
                color: active
                    ? (isDark ? const Color(0xFFE05665) : AppColors.primary)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999.sx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
