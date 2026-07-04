import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/providers/home_provider.dart';
import '../../core/models/symbol.dart';
import '../../core/enums/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import '../../shared/widgets/book_selector_menu.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../features/home/widgets/fund_group_notice.dart';
import '../../features/home/widgets/price_flash.dart';
import '../../features/auth/providers/auth_provider.dart';

/// 首页 - 1:1 复刻 uni-app pages/index/index.vue
/// 布局结构严格对齐: 标题在卡片外部, 公告和标题互斥
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _showBookMenu = false;
  bool _wasAuthenticated = false;

  // ---- 1:1 复刻 zdj pages/index/index.vue 数字颜色 ----
  // zdj .uptext_color: #EA5D70 (light & dark)
  static const _upColor = Color(0xFFEA5D70);
  // zdj .downtext_color: #10B4A1 (light & dark)
  static const _downColor = Color(0xFF10B4A1);
  // zdj .cardtop-rate--down: #00ad90 (贵金属卡片跌)
  static const _metalDownColor = Color(0xFF00AD90);

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 登录状态变化 → 刷新首页数据 (对齐 uni-app onShow login→reload)
    if (authState.isAuthenticated != _wasAuthenticated) {
      _wasAuthenticated = authState.isAuthenticated;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(homeProvider.notifier).loadHomePageData();
      });
    }
    final bgColor = isDark ? AppColors.darkBg : AppColors.homeBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ---- 固定顶部背景图 (仅浅色, 对齐 .bg/.fixed-header background-size:100% 437rpx) ----
          // 放在 SafeArea 外层，让背景延伸到状态栏后面 (状态栏透明)，
          // 否则状态栏那一条会露出纯色 Scaffold 背景，跟渐变头部断层。
          if (!isDark)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: Image(
                image: AssetImage('assets/images/img/position-bg1.png'),
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- 固定头部: Logo + 搜索 + Banner (对齐 .fixed-header) ----
                const SizedBox(height: 10),
                _buildHeader(textColor, isDark),
                const SizedBox(height: 12.5),
                _buildBanner(isDark),
                const SizedBox(height: 15),
                // ---- 可滚动内容区 (对齐 z-paging home-refresh-body) ----
                Expanded(
                  // 下拉刷新 — z-paging 风格 (对齐 uni-app home-refresh)
                  child: ZPagingRefresh(
                    isDark: isDark,
                    onRefresh: () => ref.read(homeProvider.notifier).refresh(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildGoldSilverCards(homeState.topSymbols, isDark),
                      const SizedBox(height: 15),
                      _buildMarketScroll(homeState.marketList, isDark),
                      const SizedBox(height: 15),
                      // ---- "我的资产" 区域 (标题在卡片外部上方) ----
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAssetSection(homeState, isDark),
                      ),
                      const SizedBox(height: 15),
                      _buildFundList(homeState, isDark),
                      const SizedBox(height: 70),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== Header =====
  Widget _buildHeader(Color textColor, bool isDark) {
    // zdj: 搜索图标浅色 #000000 / 深色 #D7DAE0
    final searchColor = isDark ? AppColors.darkText : const Color(0xFF000000);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(height: 30, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset('assets/images/img/logos.png', width: 30, height: 30),
            ),
            const SizedBox(width: 10),
            Text('养基助手', style: AppTextStyles.cn(16, color: textColor, weight: FontWeight.bold)),
          ]),
          GestureDetector(
            onTap: () => _handleSearch(),
            child: Icon(AppIcons.search, size: 22, color: searchColor)),
        ],
      )),
    );
  }

  // ===== Banner =====
  Widget _buildBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          isDark ? 'assets/images/img/banner1-text-white.png' : 'assets/images/img/banner1.png',
          width: double.infinity, height: 65, fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ===== Gold/Silver Cards =====
  Widget _buildGoldSilverCards(List<SymbolInfo> topSymbols, bool isDark) {
    if (topSymbols.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? null : [BoxShadow(color: const Color(0x0F2E1D0F), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        // 动画在涨跌幅徽章上(见 MetalRateBadge)，非整卡，对齐 uni-app .cardtop-rate
        child: Row(children: [
          Expanded(child: _buildMetalCard(topSymbols[0], isDark)),
          Container(width: 1, height: 70, decoration: BoxDecoration(
            gradient: isDark ? null : const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x00B7D7FF), Color(0xFFcfe3ff), Color(0xFFcfe3ff), Color(0x00B7D7FF)],
              stops: [0.0, 0.2, 0.8, 1.0],
            ),
            color: isDark ? const Color(0xFF2B2D33) : null,
          )),
          Expanded(child: _buildMetalCard(topSymbols[1], isDark)),
        ]),
      ),
    );
  }

  Widget _buildMetalCard(SymbolInfo data, bool isDark) {
    final isUp = data.isUp;
    // zdj .cardtop-rate--up bg:#EA5D70 / .cardtop-rate--down bg:#00ad90
    final priceColor = isUp ? _upColor : _metalDownColor;
    final rateColor = priceColor;

    return GestureDetector(
      onTap: () => _goMetalDetails(data),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
        child: Column(children: [
          Text(data.name, style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.metalName, height: 1.2)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(data.latestPrice?.toStringAsFixed(2) ?? '--', style: AppTextStyles.num(19, color: priceColor, weight: FontWeight.w700)),
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 1), child: Text('元/克', style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : AppColors.lightText, height: 1.2))),
          ]),
          const SizedBox(height: 12),
          // 涨跌幅徽章 (价格变动时闪烁, 1:1 uni-app .cardtop-rate)
          MetalRateBadge(
            isUp: isUp,
            isDark: isDark,
            price: data.latestPrice ?? 0,
            changeText: data.changeFormatted,
            rateText: data.changeRateFormatted,
            textColor: rateColor,
          ),
        ]),
      ),
    );
  }

  // ===== Market Indices Scroll =====
  Widget _buildMarketScroll(List<SymbolInfo> marketList, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(height: 90, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // 无左侧padding, 指数项宽度已包含间距
        itemCount: marketList.length,
        itemBuilder: (_, i) => _buildMarketItem(marketList[i], isDark),
      )),
    );
  }

  Widget _buildMarketItem(SymbolInfo item, bool isDark) {
    final isUp = item.isUp;
    final color = isUp ? _upColor : _downColor;
    final bgColor = isUp
        ? (isDark ? AppColors.darkSurface : AppColors.lightRollUpBg)
        : (isDark ? AppColors.darkSurface : AppColors.lightRollDownBg);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32) / 3; // uni-app: calc((100vw - 2rem) / 3)

    return GestureDetector(
      onTap: () => _goMarketDetails(item),
      child: Container(
        width: itemWidth,
        decoration: BoxDecoration(color: bgColor),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(item.name, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : AppColors.lightText), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(item.latestPrice?.toStringAsFixed(2) ?? '--', style: AppTextStyles.num(18, color: color, weight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item.changeFormatted, style: AppTextStyles.cn(12, color: color, weight: FontWeight.w500)),
            const SizedBox(width: 4),
            Text(item.changeRateFormatted, style: AppTextStyles.cn(12, color: color, weight: FontWeight.w500)),
            const SizedBox(width: 3),
            Image.asset(isUp ? 'assets/images/img/upico.png' : 'assets/images/img/down.png', width: 8.5, height: 8.5),
          ]),
        ]),
      ),
    );
  }

  // ===== 5. 资产区域 (标题在上, 卡片在下) =====
  Widget _buildAssetSection(HomeState state, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 公告和标题互斥 (v-if/v-else)
      if (state.hasFundGroupNotice && state.fundGroupNoticeText != null)
        FundGroupNotice(
          isDark: isDark,
          text: state.fundGroupNoticeText!,
          onClose: () => ref.read(homeProvider.notifier).dismissNotice(),
        )
      else
        Text('我的资产', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText)),
      const SizedBox(height: 11), // 22rpx margin-top between title and card
      // 资产卡片 (不含标题)
      _buildAssetCard(state, isDark),
    ]);
  }

  Widget _buildAssetCard(HomeState state, bool isDark) {
    final overview = state.assetOverview;
    final visible = state.visibleState;

    // 未登录/无资产空状态
    if (!state.hasAsset) return _buildAssetEmptyState(isDark);
    final showMoney = visible == AssetVisibleState.showAll;
    final showRatio = visible != AssetVisibleState.hideRatio;
    final isUp = (overview?.totalProfitRate ?? 0) >= 0;
    final profitTagColor = !showRatio ? AppColors.profitTagHidden : isUp ? AppColors.profitTagUp : AppColors.profitTagDown;
    final profitIcon = isUp ? 'assets/images/img/upindex.png' : 'assets/images/img/downindex.png';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140, // 280rpx 固定高度
          decoration: BoxDecoration(
            gradient: isDark ? null : const LinearGradient(
              begin: Alignment.topLeft, end: Alignment(0.3, 0.9),
              colors: [AppColors.assetGradientStart, AppColors.assetGradientEnd],
            ),
            color: isDark ? AppColors.darkSurface : null,
            borderRadius: BorderRadius.circular(11.5),
          ),
          child: Column(children: [
            // ---- top section ----
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12.5, 15, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // "总资产 - [账本]" + 眼睛
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    // topheader-t: 深色 #A7ADB8 / 浅色 #A59085
                    Text('总资产 - ', style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightGoldText, height: 1.0)),
                    GestureDetector(
                      onTap: () => setState(() => _showBookMenu = !_showBookMenu),
                      child: Row(children: [
                        // 账本名/箭头始终 #A59085 (源码硬编码, 不随主题切换)
                        Text(state.selectedBookName ?? '全部', style: AppTextStyles.cn(12, color: AppColors.lightGoldText, height: 1.0)),
                        const SizedBox(width: 1),
                        Icon(_showBookMenu ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 12, color: AppColors.lightGoldText),
                      ]),
                    ),
                  ]),
                  GestureDetector(
                    onTap: () => ref.read(homeProvider.notifier).toggleAssetVisible(),
                    child: Icon(visible == AssetVisibleState.showAll ? Icons.visibility : Icons.visibility_off, size: 22, color: AppColors.lightGoldText),
                  ),
                ]),
                const SizedBox(height: 5), // 10rpx margin-top
                // ¥金额 + profit-tag (amount-num flex:1 / profit-tag-wrapper flex:1)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(
                    showMoney ? '¥${overview?.totalAssets.toStringAsFixed(2) ?? "--"}' : '***',
                    style: AppTextStyles.num(23, color: isDark ? AppColors.darkText : const Color(0xFF333333)),
                  )),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 15), // profit-tag margin-left:30rpx
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 98, height: 25,
                        decoration: BoxDecoration(color: profitTagColor, borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (showRatio) ...[
                            Image.asset(profitIcon, width: 16.5, height: 9.5),
                            const SizedBox(width: 4),
                            Text('${isUp ? "+" : ""}${overview?.totalProfitRate.toStringAsFixed(2) ?? "--"}%',
                              style: AppTextStyles.num(15, color: AppColors.white, weight: FontWeight.w100)),
                          ] else
                            Text('***', style: AppTextStyles.num(15, color: AppColors.white)),
                        ]),
                      ),
                    ),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 10), // bottom margin-top:20rpx (分割线上方留白)
            // ---- divider ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(height: 1, color: isDark ? AppColors.assetDividerDark : AppColors.assetDivider),
            ),
            // ---- bottom section ----
            _buildAssetBottom(state, isDark),
          ]),
        ),
        // 账本下拉菜单
        if (_showBookMenu)
          Positioned(left: 0, top: 19, child: BookSelectorMenu(
            isDark: isDark, books: state.bookNames,
            selectedBook: state.selectedBookName ?? '全部',
            onSelected: (book) { setState(() => _showBookMenu = false); ref.read(homeProvider.notifier).selectBook(book); },
            onDismiss: () => setState(() => _showBookMenu = false),
          )),
      ],
    );
  }

  Widget _buildAssetBottom(HomeState state, bool isDark) {
    final overview = state.assetOverview;
    final showMoney = state.visibleState == AssetVisibleState.showAll;
    final showRatio = state.visibleState != AssetVisibleState.hideRatio;
    final metalIsUp = (overview?.metalProfit ?? 0) >= 0;
    final fundIsUp = (overview?.fundProfit ?? 0) >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 0), // padding-top:20rpx (分割线下方留白)
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildAssetSubItem('贵金属资产', showMoney ? '¥${(overview?.metalAssets ?? 0).toStringAsFixed(2)}' : '***', showRatio ? '--' : '***', metalIsUp, isDark),
        )),
        Expanded(child: Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: isDark ? AppColors.assetDividerDark : AppColors.assetDivider, width: 2))),
          child: _buildAssetSubItem('基金资产', showMoney ? '¥${(overview?.fundAssets ?? 0).toStringAsFixed(2)}' : '***', showRatio ? '${fundIsUp ? "+" : ""}${(overview?.fundProfit ?? 0).toStringAsFixed(2)}%' : '***', fundIsUp, isDark),
        )),
      ]),
    );
  }

  /// 资产卡空状态 — 1:1 复刻 uni-app .asset-card--empty
  Widget _buildAssetEmptyState(bool isDark) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: isDark ? null : const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F7)],
        ),
        color: isDark ? AppColors.darkSurface : null,
        borderRadius: BorderRadius.circular(11.5),
        border: isDark ? null : Border.all(color: const Color(0x1AE05665), width: 0.5),
        boxShadow: isDark ? null : [BoxShadow(color: const Color(0x14E05665), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10), // 22rpx 24rpx 20rpx
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // "导入你的持有基金" 按钮 (未登录点击跳转登录页)
        GestureDetector(
          onTap: () => context.push('/login'),
          child: Container(
            width: double.infinity, height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.assetEmptyBtn,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('导入你的持有基金', style: AppTextStyles.cn(13, color: Colors.white, weight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        Text('已支持支付宝、天天基金、腾讯理财通、雪球基金等平台的一键导入',
          style: AppTextStyles.cn(9.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8B8B8B), height: 1.3), textAlign: TextAlign.center),
        const SizedBox(height: 10), // 20rpx margin-top
        Text('养基助手应用仅用于数据同步模拟，不涉及任何真实交易',
          style: AppTextStyles.cn(8.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB0B0B0), height: 1.3), textAlign: TextAlign.center),
      ]),
    );
  }

  // uni-app: asset-card__item-row = flex justify-between (金额和百分比左右排列)
  Widget _buildAssetSubItem(String label, String value, String rate, bool isUp, bool isDark) {
    final rateColor = isUp ? _upColor : _downColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // item-label: 深色 #A7ADB8 / 浅色 #A08F82
      Text(label, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA08F82), height: 1.0)),
      const SizedBox(height: 10), // 20rpx margin-top
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // item-value: 深色 #D7DAE0 / 浅色 #3D3D3D
        Text(value, style: AppTextStyles.num(11, color: isDark ? AppColors.darkText : const Color(0xFF3D3D3D), weight: FontWeight.w600)),
        Text(rate, style: AppTextStyles.num(11, color: rateColor, weight: FontWeight.w500)),
      ]),
    ]);
  }

  // ===== 6. Fund List =====
  Widget _buildFundList(HomeState state, bool isDark) {
    final funds = state.fundList;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('基金列表', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 11),
        // 对齐 uni-app：未登录=热门基金榜(getFundHeatTop)，空列表只留标题、无占位卡
        if (funds.isNotEmpty)
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 88.5, // 177rpx 精确高度, 不依赖 childAspectRatio
              crossAxisSpacing: 8,  // 16rpx gap
              mainAxisSpacing: 8,   // 16rpx gap
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: funds.length.clamp(0, 10),
            itemBuilder: (_, i) => _buildFundItemData(funds[i], isDark),
          ),
      ]),
    );
  }

  // ==================== 导航方法 ====================
  void _handleSearch() {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/search');
  }

  void _goMetalDetails(SymbolInfo item) {
    if (item.symbolId == null) return;
    context.push('/position-details?symbolId=${item.symbolId}&assetType=7');
  }

  void _goMarketDetails(SymbolInfo item) {
    if (item.symbolId == null) return;
    context.push('/market-details?symbolId=${item.symbolId}&name=${Uri.encodeComponent(item.name)}');
  }

  void _goFundDetails(SymbolInfo item) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/position-details?symbolId=${item.symbolId}&assetType=${item.assetType ?? 3}&assetId=${item.assetId ?? ''}');
  }

  /// 基于 API 数据的基金项 (1:1 复刻 uni-app funditem)
  /// 三行结构: head(标题+代码) / middle(基金类型+涨跌幅) / bottom(净值+涨跌额)
  Widget _buildFundItemData(SymbolInfo item, bool isDark) {
    final isUp = (item.changeRate ?? 0) >= 0;
    final rateColor = isUp ? _upColor : _downColor;
    final title = item.name;           // funditem__title (shortName)
    final code = item.code;
    final typeName = item.typeName ?? ''; // funditem__name (fundTypeName)
    final price = item.latestPrice?.toStringAsFixed(4) ?? '--';
    final rate = item.changeRate != null ? '${item.changeRate! >= 0 ? "+" : ""}${item.changeRate!.toStringAsFixed(2)}%' : '--';
    final change = item.change != null ? '${item.change! >= 0 ? "+" : ""}${item.change!.toStringAsFixed(2)}' : '+0.00';

    return GestureDetector(
      onTap: () => _goFundDetails(item),
      child: Container(
        // height 由 GridView mainAxisExtent: 88.5 控制
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
        decoration: BoxDecoration(
          gradient: isDark ? null : (isUp
              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.fundUpGradientStart, AppColors.fundUpGradientEnd])
              : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.fundDownGradientStart, AppColors.fundDownGradientEnd])),
          color: isDark ? AppColors.darkSurface : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // head: 标题 + 代码标签
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : AppColors.fundItemTitle, height: 1.2))),
            const SizedBox(width: 6),
            Container(
              width: 42.5, height: 15.5, alignment: Alignment.center,
              decoration: BoxDecoration(color: isDark ? AppColors.fundCodeBgDark : AppColors.fundCodeBg, borderRadius: BorderRadius.circular(6)),
              child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cn(9, color: isDark ? AppColors.fundCodeTextDark : AppColors.fundCodeText)),
            ),
          ]),
          // middle: 基金类型 + 涨跌幅
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Flexible(child: Text(typeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.fundItemName, height: 1.0))),
            const SizedBox(width: 5),
            Text(rate, style: AppTextStyles.num(14, color: rateColor, weight: FontWeight.w700)),
          ]),
          // bottom: 净值 + 涨跌额 (涨跌额随涨跌着色)
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(price, style: AppTextStyles.num(9.5, color: isDark ? AppColors.darkText : AppColors.fundItemPrice, height: 1.0)),
            const SizedBox(width: 7),
            Text(change, style: AppTextStyles.num(9.5, color: rateColor, height: 1.0)),
          ]),
        ]),
      ),
    );
  }
}
