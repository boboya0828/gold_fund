import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/home/home_format.dart';
import '../../core/models/symbol.dart';
import '../../core/enums/enums.dart';
import '../../core/network/api_endpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import '../../shared/widgets/book_selector_menu.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../features/home/widgets/fund_group_notice.dart';
import '../../features/home/widgets/price_flash.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'widgets/market_roll_item.dart';

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
  // zdj .cardtop-rate--down 浅色文字色: #00ad90 (深色为 #10B4A1)
  static const _metalDownTextLight = Color(0xFF00AD90);

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
                _buildBanner(homeState, isDark),
                const SizedBox(height: 15),
                // ---- 可滚动内容区 (对齐 z-paging home-refresh-body) ----
                Expanded(
                  // 下拉刷新 — z-paging 风格 (对齐 uni-app home-refresh)
                  child: ZPagingRefresh(
                    isDark: isDark,
                    // refresher-title-style: 浅 #555555 / 深 #A7ADB8
                    titleColor: isDark
                        ? const Color(0xFFA7ADB8)
                        : const Color(0xFF555555),
                    onRefresh: () => ref.read(homeProvider.notifier).refresh(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildGoldSilverCards(homeState.topSymbols, isDark),
                      const SizedBox(height: 15),
                      _buildMarketScroll(homeState, isDark),
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
  // 对齐 uni-app homeBannerSrc: 优先接口 banner (themeType '0'浅/'1'深 且 imageUrl 含 'banner'),
  // 否则本地默认图; 源码无圆角
  Widget _buildBanner(HomeState state, bool isDark) {
    final themeType = isDark ? '1' : '0';
    String? url;
    for (final b in state.banners) {
      if (b.themeType == themeType &&
          b.imageUrl.toLowerCase().contains('banner')) {
        url = _fullImageUrl(b.imageUrl);
        break;
      }
    }
    final fallback = Image.asset(
      isDark
          ? 'assets/images/img/banner1-text-white.png'
          : 'assets/images/img/banner1.png',
      width: double.infinity, height: 65, fit: BoxFit.cover, // 130rpx
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: url == null
          ? fallback
          : Image.network(
              url,
              width: double.infinity, height: 65, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }

  // getFullImageUrl
  String _fullImageUrl(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return r;
    if (r.startsWith('http://') ||
        r.startsWith('https://') ||
        r.startsWith('//') ||
        r.startsWith('data:') ||
        r.startsWith('/static/')) {
      return r;
    }
    return r.startsWith('/') ? '${ApiEndpoints.baseUrl}$r' : r;
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
    // getRealtimeTrendValue: increaseRaw ≠ 0 ? raw : (ratioRaw ≠ 0 ? ratio : 0)
    final change = data.change;
    final trend = (change != null && change != 0) ? change : (data.changeRate ?? 0);
    // getGoldTrendClass: >0 涨 / <0 跌 / ==0 基础色 #111111 (源码深色未覆盖, 保持一致)
    final priceColor =
        trend > 0 ? _upColor : (trend < 0 ? _downColor : AppColors.metalPrice);
    // 徽章: >0 up, 否则 down (flat 归 down, 对齐源码三元表达式)
    final badgeUp = trend > 0;
    final badgeTextColor =
        badgeUp ? _upColor : (isDark ? _downColor : _metalDownTextLight);
    final price = data.latestPrice;

    // uni-app goMetalPositionDetails 已禁用跳转 (源码 return;), 点击不导航
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      child: Column(children: [
        Text(data.name, style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.metalName, height: 1.2)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          // getPriceDigits: <100 保留3位, 其他2位
          Text(homeFmtDecimal(price, homePriceDigits(price), '0.00'),
              style: AppTextStyles.num(19, color: priceColor, weight: FontWeight.w700)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 1), child: Text('元/克', style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : AppColors.lightText, height: 1.2))),
        ]),
        const SizedBox(height: 12),
        // 涨跌幅徽章 (价格变动时闪烁, 1:1 uni-app .cardtop-rate)
        MetalRateBadge(
          isUp: badgeUp,
          isDark: isDark,
          price: price ?? 0,
          changeText: homeFmtSignedAmount(change, 2),
          rateText: homeFmtSignedPercent(data.changeRate, 2),
          textColor: badgeTextColor,
        ),
      ]),
    );
  }

  // ===== Market Indices Scroll =====
  Widget _buildMarketScroll(HomeState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(height: 90, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // 无左侧padding, 指数项宽度已包含间距
        itemCount: state.marketList.length,
        itemBuilder: (_, i) {
          final item = state.marketList[i];
          return MarketRollItem(
            item: item,
            isDark: isDark,
            flashUp: state.marketFlashes[item.id],
            onTap: () => _goMarketDetails(item),
          );
        },
      )),
    );
  }

  // ===== 5. 资产区域 (标题在上, 卡片在下) =====
  Widget _buildAssetSection(HomeState state, bool isDark) {
    // hendleiSlogin: 整个 box-card2 可点; 未登录 → 登录页, 已登录 → 持仓 tab
    // (内部 账本切换/眼睛/收益标签/公告 均有点击拦截, 对齐 @click.stop)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!state.isLoggedIn) {
          context.push('/login');
        } else {
          context.go('/position');
        }
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 公告和标题互斥 (v-if/v-else)
        if (state.hasFundGroupNotice)
          FundGroupNotice(
            isDark: isDark,
            text: state.fundGroupNoticeText,
            // uni-app 点击打开微信基金群小程序 (平台能力, 不实现); 仅拦截避免触发整卡跳转
            onTap: () {},
            onClose: () => ref.read(homeProvider.notifier).dismissNotice(),
          )
        else
          Text('我的资产', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 11), // 22rpx margin-top between title and card
        // 资产卡片 (不含标题); 空状态仅未登录展示 (对齐 v-if="userInfo")
        state.isLoggedIn
            ? _buildAssetCard(state, isDark)
            : _buildAssetEmptyState(isDark),
      ]),
    );
  }

  Widget _buildAssetCard(HomeState state, bool isDark) {
    final summary = state.assetSummary;
    final visible = state.visibleState;

    // showAssetMoney / showAssetRatio
    final showMoney = visible == AssetVisibleState.showAll;
    final showRatio = visible != AssetVisibleState.hideRatio;
    // showAssetProfitTag = amount 模式 ? showMoney : showRatio
    final amountMode = state.profitDisplayMode == 'amount';
    final showTag = amountMode ? showMoney : showRatio;
    final amountValue = homeParseProfit(summary.totalProfit);
    final ratioValue = homeParseProfit(summary.totalProfitRatio) ?? 0;
    final displayValue = amountMode ? amountValue : ratioValue;
    // assetProfitTagClass: 不可见或值无效 → hidden 灰
    final tagHidden = !showTag || displayValue == null;
    final displayNum = displayValue ?? 0;
    final tagColor = tagHidden
        ? AppColors.profitTagHidden
        : (displayNum < 0 ? AppColors.profitTagDown : AppColors.profitTagUp);
    final showTagIcon = showTag && displayValue != null;
    final tagIcon = displayNum < 0
        ? 'assets/images/img/downindex.png'
        : 'assets/images/img/upindex.png';
    // assetProfitDisplayText
    final tagText = !showTag
        ? '***'
        : (amountMode
            ? (amountValue == null ? '--' : homeFmtSignedAmount(amountValue))
            : summary.totalProfitRatio);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140, // 280rpx 固定高度
          decoration: BoxDecoration(
            gradient: isDark ? null : const LinearGradient(
              // 133deg ≈ 方向向量 (sin133°, -cos133°)
              begin: Alignment(-0.731, -0.682), end: Alignment(0.731, 0.682),
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
                    Text('总资产 -', style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightGoldText, height: 1.0)),
                    const SizedBox(width: 2), // topheader-main gap 4rpx
                    GestureDetector(
                      onTap: () => setState(() => _showBookMenu = !_showBookMenu),
                      child: Row(children: [
                        // 账本名/箭头始终 #A59085 (源码硬编码, 不随主题切换)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 64), // max-width 128rpx
                          child: Text(state.currentBookName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cn(12, color: AppColors.lightGoldText, height: 1.0)),
                        ),
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
                // ￥金额 + profit-tag (amount-num flex:1 / profit-tag-wrapper flex:1)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(
                    showMoney ? '￥${summary.totalMarketValue}' : '***',
                    style: AppTextStyles.num(23, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600),
                  )),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 15), // profit-tag margin-left:30rpx
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // 收益标签可点: 比例/金额切换 (toggleAssetProfitDisplay)
                      child: GestureDetector(
                        onTap: () => ref.read(homeProvider.notifier).toggleProfitDisplayMode(),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 98), // min-width 196rpx
                          height: 25,
                          padding: const EdgeInsets.symmetric(horizontal: 9), // 0 18rpx
                          decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                            if (showTagIcon) ...[
                              Image.asset(tagIcon, width: 16.5, height: 9.5),
                              const SizedBox(width: 4),
                            ],
                            Text(tagText, style: AppTextStyles.num(15, color: AppColors.white, weight: FontWeight.w100)),
                          ]),
                        ),
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
            _buildAssetBottom(state, isDark, showTag, amountMode),
          ]),
        ),
        // 账本下拉菜单 (相对 topheader-main: left 0 / top 38rpx → 卡片内 15 / 31.5)
        if (_showBookMenu)
          Positioned(left: 15, top: 31.5, child: BookSelectorMenu(
            isDark: isDark,
            options: state.bookOptions,
            selectedValue: state.selectedBookValue,
            onSelected: (value) {
              setState(() => _showBookMenu = false);
              ref.read(homeProvider.notifier).selectBook(value);
            },
            onDismiss: () => setState(() => _showBookMenu = false),
          )),
      ],
    );
  }

  Widget _buildAssetBottom(HomeState state, bool isDark, bool showTag, bool amountMode) {
    final summary = state.assetSummary;
    final showMoney = state.visibleState == AssetVisibleState.showAll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 0), // padding-top:20rpx (分割线下方留白)
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildAssetSubItem(
            '贵金属资产',
            showMoney ? '￥${summary.metalMarketValue}' : '***',
            summary.metalProfit, summary.metalProfitRatio,
            showTag, amountMode, isDark,
          ),
        )),
        Expanded(child: Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: isDark ? AppColors.assetDividerDark : AppColors.assetDivider, width: 1))), // 2rpx
          child: _buildAssetSubItem(
            '基金资产',
            showMoney ? '￥${summary.fundMarketValue}' : '***',
            summary.fundProfit, summary.fundProfitRatio,
            showTag, amountMode, isDark,
          ),
        )),
      ]),
    );
  }

  // uni-app: asset-card__item-row = flex justify-between (金额和百分比左右排列)
  Widget _buildAssetSubItem(String label, String value, String profitAmount,
      String profitRatio, bool showTag, bool amountMode, bool isDark) {
    // getAssetItemProfitText
    final String rateText;
    if (!showTag) {
      rateText = '***';
    } else if (amountMode) {
      final profitNum = homeParseProfit(profitAmount);
      rateText = profitNum == null ? '--' : homeFmtSignedAmount(profitNum);
    } else {
      rateText = profitRatio;
    }
    // getAssetItemRateClass: 无 class 时为基础色 #EA5D70; 仅 <0 显示跌色
    final rateNum = homeParseProfit(amountMode ? profitAmount : profitRatio);
    final rateColor =
        (showTag && rateNum != null && rateNum < 0) ? _downColor : _upColor;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // item-label: 深色 #A7ADB8 / 浅色 #A08F82
      Text(label, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA08F82), height: 1.0)),
      const SizedBox(height: 10), // 20rpx margin-top
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // item-value: 深色 #D7DAE0 / 浅色 #3D3D3D
        Text(value, style: AppTextStyles.num(11, color: isDark ? AppColors.darkText : const Color(0xFF3D3D3D), weight: FontWeight.w600)),
        Text(rateText, style: AppTextStyles.num(11, color: rateColor, weight: FontWeight.w500)),
      ]),
    ]);
  }

  /// 资产卡空状态 — 1:1 复刻 uni-app .asset-card--empty (仅未登录展示)
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
        // 源码深色未覆盖空卡边框, 明暗都保留
        border: Border.all(color: const Color(0x1AE05665), width: 0.5),
        boxShadow: isDark ? null : [BoxShadow(color: const Color(0x14E05665), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10), // 22rpx 24rpx 20rpx
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // "导入你的持有基金" 按钮 (点击由父级 box-card2 统一处理 → 登录页)
        Container(
          width: double.infinity, height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.assetEmptyBtn,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text('导入你的持有基金', style: AppTextStyles.cn(13, color: Colors.white, weight: FontWeight.w600)),
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

  // ===== 6. Fund List =====
  Widget _buildFundList(HomeState state, bool isDark) {
    final funds = state.fundList;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('基金列表', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 11),
        // 对齐 uni-app：未登录=热门基金榜(getFundHeatTop 取前10)，登录=全部持仓基金(不截断)
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
            padding: const EdgeInsets.only(bottom: 15), // .fundlist padding-bottom 30rpx
            itemCount: funds.length,
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

  void _goMarketDetails(SymbolInfo item) {
    if (item.symbolId == null) return;
    context.push('/market-details?symbolId=${item.symbolId}&name=${Uri.encodeComponent(item.name)}');
  }

  void _goFundDetails(SymbolInfo item) {
    if (item.symbolId == null) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/position-details?symbolId=${item.symbolId}&assetType=${item.assetType ?? 3}&assetId=${item.assetId ?? ''}');
  }

  /// 基于 API 数据的基金项 (1:1 复刻 uni-app funditem)
  /// 三行结构: head(标题+代码) / middle(基金类型+涨跌幅) / bottom(净值+涨跌百分比)
  Widget _buildFundItemData(SymbolInfo item, bool isDark) {
    // rateValue: hot → lp.chgRate 原值; asst → dayChangeRatio ?? 0
    final rateValue = item.changeRate;
    // funditem--cool 仅当 rateValue < 0 (flat 归 warm)
    final cool = (rateValue ?? 0) < 0;
    // rate/change 颜色: >0 涨 / <0 跌 / ==0 或 null → 基础色 (rate #ff4b52, change #353535)
    final rateColor = rateValue != null && rateValue > 0
        ? _upColor
        : (rateValue != null && rateValue < 0 ? _downColor : AppColors.fundRateDefault);
    final changeColor = rateValue != null && rateValue > 0
        ? _upColor
        : (rateValue != null && rateValue < 0
            ? _downColor
            : (isDark ? AppColors.darkText : AppColors.fundItemPrice));
    final priceText = homeFmtDecimal(item.latestPrice, 4, '--');
    final rateText = homeFmtSignedPercent(rateValue, 2);
    // uni-app: change 恒为百分比 (chgRate ?? changeRatio), 缺失 → '+0.00%'
    final changeText = homeFmtSignedPercent(item.change, 2);

    return GestureDetector(
      onTap: () => _goFundDetails(item),
      child: Container(
        // height 由 GridView mainAxisExtent: 88.5 控制
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
        decoration: BoxDecoration(
          gradient: isDark ? null : (!cool
              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.fundUpGradientStart, AppColors.fundUpGradientEnd])
              : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.fundDownGradientStart, AppColors.fundDownGradientEnd])),
          color: isDark ? AppColors.darkSurface : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // head: 标题 + 代码标签
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(12, color: isDark ? AppColors.darkText : AppColors.fundItemTitle, height: 1.2))),
            const SizedBox(width: 6),
            Container(
              width: 42.5, height: 15.5, alignment: Alignment.center,
              decoration: BoxDecoration(color: isDark ? AppColors.fundCodeBgDark : AppColors.fundCodeBg, borderRadius: BorderRadius.circular(6)),
              child: Text(item.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cn(9, color: isDark ? AppColors.fundCodeTextDark : AppColors.fundCodeText)),
            ),
          ]),
          // middle: 基金类型 + 涨跌幅
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Flexible(child: Text(item.typeName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.fundItemName, height: 1.0))),
            const SizedBox(width: 5),
            Text(rateText, style: AppTextStyles.num(14, color: rateColor, weight: FontWeight.w700)),
          ]),
          // bottom: 净值 + 涨跌百分比
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(priceText, style: AppTextStyles.num(9.5, color: isDark ? AppColors.darkText : AppColors.fundItemPrice, height: 1.0)),
            const SizedBox(width: 7),
            Text(changeText, style: AppTextStyles.num(9.5, color: changeColor, height: 1.0)),
          ]),
        ]),
      ),
    );
  }
}
