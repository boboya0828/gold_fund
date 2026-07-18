import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_colors.dart';

import 'pages/home/home_page.dart';
import 'pages/position/position_page.dart';
import 'pages/position/position_details_page.dart';
import 'pages/position/position_sort_page.dart';
import 'pages/position/position_search_page.dart';
import 'pages/position/batch_adjust_page.dart';
import 'pages/position/trading_record_page.dart';
import 'pages/optional/optional_page.dart';
import 'pages/optional/optional_search_page.dart';
import 'pages/optional/ledger_page.dart';
import 'pages/optional/widgets/ledger_book_api.dart';
import 'pages/market/market_page.dart';
import 'pages/market/market_details_page.dart';
import 'pages/market/plate_ranking_page.dart';
import 'pages/market/plate_data_page.dart';
import 'pages/market/selected_list_page.dart';
import 'pages/member/member_page.dart';
import 'pages/member/morning_news_page.dart';
import 'pages/member/closing_news_page.dart';
import 'pages/member/member_details_page.dart';
import 'pages/member/contrast_page.dart';
import 'pages/member/rising_chart_page.dart';
import 'pages/member/open_member_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/user/curve_page.dart';
import 'pages/user/distribution_page.dart';
import 'pages/user/profit_detail_page.dart';
import 'pages/user/profile_edit_page.dart';
import 'pages/user/nickname_page.dart';
import 'pages/user/bound_phone_page.dart';
import 'pages/user/skin_page.dart';
import 'pages/user/share_page.dart';
import 'pages/user/settings_page.dart';
import 'pages/common/webview_page.dart';
import 'pages/common/privacy_auth_page.dart';
import 'pages/common/guide_page.dart';
import 'pages/fund/running_tab_page.dart';
import 'pages/fund/fund_settings_page.dart';
import 'pages/fund/listed_net_value_page.dart';
import 'pages/fund/stage_revenue_page.dart';
import 'pages/fund/fund_trading_record_page.dart';
import 'pages/fund/gjs_bookkeeping_page.dart';
import 'pages/fund/gjs_holding_edit_page.dart';
import 'pages/fund/upload/mass_upload_page.dart';
import 'pages/fund/upload/add_accounting_records_page.dart';
import 'pages/fund/upload/upload_search_page.dart';
import 'pages/fund/upload/mass_upload_madd_page.dart';
import 'pages/fund/upload/mass_upload_maddzx_page.dart';
import 'pages/fund/upload/ocr_result_page.dart';
import 'features/auth/pages/wx_login_page.dart';
import 'features/auth/pages/phone_login_page.dart';
import 'features/auth/pages/phone_code_page.dart';
import 'features/auth/pages/password_login_page.dart';

/// GoRouter 路由配置 - 匹配 uni-app pages.json 的页面结构
///
/// 路由层次:
///   /login          → 微信登录主页面 (无 TabBar)
///   /login/phone    → 手机号输入页 (无 TabBar)
///   /login/phone-code → 验证码输入页 (无 TabBar)
///   /login/password → 密码登录页 (无 TabBar)
///   /home           → 首页 (Tab 0)
///   /position       → 持仓 (Tab 1, 需登录)
///   /optional       → 自选 (Tab 2, 需登录)
///   /market         → 行情 (Tab 3)
///   /member         → 会员 (Tab 4)
///   /profile        → 我的 (Tab 5)
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  // 单例，避免重复创建导致 GlobalKey 冲突
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
      routes: [
        // ===== 登录路由 (无 TabBar) =====
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WxLoginPage(),
          ),
          routes: [
            GoRoute(
              path: 'phone',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PhoneLoginPage(),
              ),
            ),
            GoRoute(
              path: 'phone-code',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PhoneCodePage(),
              ),
            ),
            GoRoute(
              path: 'password',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PasswordLoginPage(),
              ),
            ),
          ],
        ),

        // ===== 隐私授权 / 引导页 (无 TabBar) =====
        GoRoute(
          path: '/privacy-auth',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PrivacyAuthPage(),
          ),
        ),
        GoRoute(
          path: '/guide',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GuidePage(),
          ),
        ),

        // ===== Tab Shell =====
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return MainShell(child: child);
          },
          routes: [
            // 首页
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomePage(),
              ),
            ),
            // 持仓
            GoRoute(
              path: '/position',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PositionPage(),
              ),
              redirect: _authGuard,
            ),
            // 自选
            GoRoute(
              path: '/optional',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: OptionalPage(),
              ),
              redirect: _authGuard,
            ),
            // 行情
            GoRoute(
              path: '/market',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MarketPage(),
              ),
            ),
            // 会员
            GoRoute(
              path: '/member',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MemberPage(),
              ),
            ),
            // 我的
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfilePage(),
              ),
            ),

            // ===== 子页面 (带 TabBar) =====
            // 持仓详情
            GoRoute(
              path: '/position-details',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                final symbolId = q['symbolId'] ?? '';
                final assetType = int.tryParse(q['assetType'] ?? '3') ?? 3;
                final assetId = int.tryParse(q['assetId'] ?? '');
                return NoTransitionPage(
                  child: PositionDetailsPage(
                    symbolId: symbolId,
                    assetType: assetType,
                    assetId: assetId,
                    bookId: int.tryParse(q['bookId'] ?? ''),
                    fromAllBooks: q['fromAllBooks'] == '1' || q['fromAllBooks'] == 'true',
                  ),
                );
              },
            ),
            // 持仓排序管理
            GoRoute(
              path: '/position-sort',
              pageBuilder: (context, state) => NoTransitionPage(
                child: PositionSortPage(
                  bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? ''),
                ),
              ),
            ),
            // 持仓搜索 (from=trading-record 时 pop 返回选中基金)
            GoRoute(
              path: '/position-search',
              pageBuilder: (context, state) => NoTransitionPage(
                child: PositionSearchPage(
                  from: state.uri.queryParameters['from'] ?? '',
                  bookId: state.uri.queryParameters['bookId'] ?? '',
                ),
              ),
            ),
            // 批量加减仓
            GoRoute(
              path: '/batch-adjust',
              pageBuilder: (context, state) => NoTransitionPage(
                child: BatchAdjustPage(
                  bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? ''),
                  preSelectedAssetId: int.tryParse(
                      state.uri.queryParameters['preSelectedAssetId'] ?? ''),
                ),
              ),
            ),
            // 交易记录 (持仓 tab)
            GoRoute(
              path: '/trading-record',
              pageBuilder: (context, state) => NoTransitionPage(
                child: TradingRecordPage(
                  bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? ''),
                  fundCode: state.uri.queryParameters['fundCode'] ?? '',
                  fundName: state.uri.queryParameters['fundName'] ?? '',
                ),
              ),
            ),
            // ===== 基金管理子页 (pages/index/fund/*) =====
            // 添加交易流水 (加仓/减仓/定投/转换)
            GoRoute(
              path: '/fund/running-tab',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: RunningTabPage(
                    activeTab: q['activeTab'] ?? 'buy',
                    uniqueSymbol: q['uniqueSymbol'] ?? '',
                    shortName: q['shortName'] ?? '',
                    symbolId: int.tryParse(q['symbolId'] ?? ''),
                    assetId: q['assetId'] ?? '',
                    bookId: int.tryParse(q['bookId'] ?? '') ?? 0,
                  ),
                );
              },
            ),
            // 基金设置
            GoRoute(
              path: '/fund/settings',
              pageBuilder: (context, state) => NoTransitionPage(
                child: FundSettingsPage(
                  symbolId: state.uri.queryParameters['symbolId'],
                  assetId: state.uri.queryParameters['assetId'],
                ),
              ),
            ),
            // 历史净值
            GoRoute(
              path: '/fund/listed-net-value',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ListedNetValuePage(
                  symbolId: int.tryParse(
                      state.uri.queryParameters['symbolId'] ?? ''),
                ),
              ),
            ),
            // 阶段收益
            GoRoute(
              path: '/fund/stage-revenue',
              pageBuilder: (context, state) => NoTransitionPage(
                child: StageRevenuePage(
                  symbolId: int.tryParse(
                      state.uri.queryParameters['symbolId'] ?? ''),
                ),
              ),
            ),
            // 基金交易记录
            GoRoute(
              path: '/fund/trading-record',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: FundTradingRecordPage(
                    shortName: q['shortName'] ?? '',
                    symbolId: q['symbolId'] ?? '',
                    symbolCode: q['symbolCode'] ?? '',
                    assetId: q['assetId'] ?? '',
                    bookId: int.tryParse(q['bookId'] ?? ''),
                    fromAllBooks:
                        q['fromAllBooks'] == '1' || q['fromAllBooks'] == 'true',
                  ),
                );
              },
            ),
            // 贵金属记账
            GoRoute(
              path: '/fund/gjs-bookkeeping',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: GjsBookkeepingPage(
                    activeTab: q['activeTab'] ?? 'buy',
                    uniqueSymbol: q['uniqueSymbol'] ?? '',
                    shortName: q['shortName'] ?? '',
                    symbolId: int.tryParse(q['symbolId'] ?? ''),
                    assetId: q['assetId'] ?? '',
                    bookId: int.tryParse(q['bookId'] ?? '') ?? 0,
                  ),
                );
              },
            ),
            // 贵金属持仓编辑
            GoRoute(
              path: '/fund/gjs-holding-edit',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: GjsHoldingEditPage(
                    assetId: q['assetId'] ?? '',
                    bookId: q['bookId'] ?? '',
                    symbolId: q['symbolId'] ?? '',
                    uniqueSymbol: q['uniqueSymbol'] ?? '',
                    shortName: q['shortName'] ?? '',
                    holdQuantity: q['holdQuantity'] ?? '',
                    holdCostAmount: q['holdCostAmount'] ?? '',
                    comment: q['comment'] ?? '',
                  ),
                );
              },
            ),
            // ===== 同步持仓/批量导入 (pages/index/fund/upload/*) =====
            GoRoute(
              path: '/fund/upload/mass-upload',
              pageBuilder: (context, state) => NoTransitionPage(
                child: MassUploadPage(
                  bookId: state.uri.queryParameters['bookId'],
                ),
              ),
            ),
            GoRoute(
              path: '/fund/upload/add-records',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: AddAccountingRecordsPage(
                    shortName: q['shortName'] ?? '',
                    fromDetails: q['fromDetails'] == '1',
                    mode: q['mode'] ?? 'add',
                    symbolId: int.tryParse(q['symbolId'] ?? ''),
                    marketValue: q['marketValue'] ?? '',
                    holdProfit: q['holdProfit'] ?? '',
                  ),
                );
              },
            ),
            GoRoute(
              path: '/fund/upload/search',
              pageBuilder: (context, state) => NoTransitionPage(
                child: UploadSearchPage(
                  bookId: state.uri.queryParameters['bookId'],
                  selectMode:
                      state.uri.queryParameters['selectMode'] ?? 'navigate',
                  entryKey: state.uri.queryParameters['entryKey'] ?? '',
                ),
              ),
            ),
            GoRoute(
              path: '/fund/upload/madd',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: MassUploadMaddPage(
                    bookId: q['bookId'],
                    uniqueSymbol: q['uniqueSymbol'],
                    shortName: q['shortName'],
                    symbolId: q['symbolId'],
                    assetAmount: q['assetAmount'],
                    profitAmount: q['profitAmount'],
                  ),
                );
              },
            ),
            GoRoute(
              path: '/fund/upload/maddzx',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                return NoTransitionPage(
                  child: MassUploadMaddzxPage(
                    mode: q['mode'],
                    shortName: q['shortName'],
                    symbolId: q['symbolId'],
                    bookId: q['bookId'],
                    marketValue: q['marketValue'],
                    holdProfit: q['holdProfit'],
                  ),
                );
              },
            ),
            GoRoute(
              path: '/fund/upload/ocr-result',
              pageBuilder: (context, state) => NoTransitionPage(
                child: OcrResultPage(
                  bookId: state.uri.queryParameters['bookId'],
                  data: state.uri.queryParameters['data'],
                ),
              ),
            ),
            // 行情详情
            GoRoute(
              path: '/market-details',
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters;
                final symbolId = q['symbolId'] ?? '';
                final name = q['name'];
                return NoTransitionPage(
                  child: MarketDetailsPage(
                    symbolId: symbolId,
                    name: name,
                    source: q['source'],
                    initialTab: q['tab'],
                  ),
                );
              },
            ),
            // 板块排行
            GoRoute(
              path: '/plate-ranking',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PlateRankingPage(),
              ),
            ),
            // 板块数据
            GoRoute(
              path: '/plate-data',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PlateDataPage(),
              ),
            ),
            // 精选榜单 (tab=hot/selected/holding/rise/streak)
            GoRoute(
              path: '/selected-list',
              pageBuilder: (context, state) => NoTransitionPage(
                child: SelectedListPage(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ),
            // 自选搜索
            GoRoute(
              path: '/optional-search',
              pageBuilder: (context, state) => NoTransitionPage(
                child: OptionalSearchPage(
                  bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? '') ?? 0,
                ),
              ),
            ),
            // 分组/账本管理 (type=asset 时为持仓账本)
            GoRoute(
              path: '/ledger',
              pageBuilder: (context, state) => NoTransitionPage(
                child: LedgerPage(
                  bookType: state.uri.queryParameters['type'] == 'asset'
                      ? LedgerBookType.asset
                      : LedgerBookType.favorite,
                ),
              ),
            ),
            // 会员子页
            GoRoute(
              path: '/member/morning-news',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MorningNewsPage(),
              ),
            ),
            GoRoute(
              path: '/member/closing-news',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ClosingNewsPage(),
              ),
            ),
            GoRoute(
              path: '/member/details',
              pageBuilder: (context, state) => NoTransitionPage(
                child: MemberDetailsPage(
                  type: state.uri.queryParameters['type'] ?? 'morning',
                  id: state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ),
            GoRoute(
              path: '/member/contrast',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ContrastPage(),
              ),
            ),
            GoRoute(
              path: '/member/rising-chart',
              pageBuilder: (context, state) => NoTransitionPage(
                child: RisingChartPage(
                  period: state.uri.queryParameters['period'] ?? 'today',
                  detailId: state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ),
            GoRoute(
              path: '/member/open-member',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: OpenMemberPage(),
              ),
            ),
            // 用户子页
            GoRoute(
              path: '/user/curve',
              pageBuilder: (context, state) => NoTransitionPage(
                child: UserCurvePage(
                  bookId: state.uri.queryParameters['bookId'],
                ),
              ),
            ),
            GoRoute(
              path: '/user/distribution',
              pageBuilder: (context, state) => NoTransitionPage(
                child: DistributionPage(
                  bookId: state.uri.queryParameters['bookId'],
                  type: state.uri.queryParameters['type'],
                ),
              ),
            ),
            GoRoute(
              path: '/user/profit-detail',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ProfitDetailPage(
                  bookId: state.uri.queryParameters['bookId'],
                  date: state.uri.queryParameters['date'],
                ),
              ),
            ),
            GoRoute(
              path: '/user/nickname',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NicknamePage(),
              ),
            ),
            GoRoute(
              path: '/user/bound-phone',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: BoundPhonePage(),
              ),
            ),
            GoRoute(
              path: '/user/skin',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SkinPage(),
              ),
            ),
            GoRoute(
              path: '/user/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfileEditPage(),
              ),
            ),
            GoRoute(
              path: '/user/share',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SharePage(),
              ),
            ),
            GoRoute(
              path: '/user/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsPage(),
              ),
            ),
            // 公关页面
            GoRoute(
              path: '/privacy',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: WebViewPage(title: '隐私政策'),
              ),
            ),
            GoRoute(
              path: '/agreement',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: WebViewPage(title: '用户协议'),
              ),
            ),
          ],
        ),
      ],
    );

  /// 认证守卫: 持仓、自选需要登录，未登录跳转登录页
  static Future<String?> _authGuard(
      BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      return '/login';
    }
    return null;
  }
}

/// Shell 主框架 - 包含底部导航栏
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _routes = [
    '/home', '/position', '/optional', '/market', '/member', '/profile'
  ];

  @override
  Widget build(BuildContext context) {
    // 根据当前路由同步 tab 索引
    final location = GoRouterState.of(context).uri.toString();
    final idx = _routes.indexOf(location);
    if (idx >= 0) _currentIndex = idx;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildTabBar(context),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 浅色模式: dark icons; 深色模式: black icons
    final tabs = [
      _TabData('assets/tab_icons/home.png', 'assets/tab_icons/home-a.png',
          isDark ? 'assets/tab_icons/home-black.png' : 'assets/tab_icons/home.png', '首页'),
      _TabData('assets/tab_icons/position.png', 'assets/tab_icons/position-a.png',
          isDark ? 'assets/tab_icons/position-black.png' : 'assets/tab_icons/position.png', '持仓'),
      _TabData('assets/tab_icons/taboptional.png', 'assets/tab_icons/tab_optional.png',
          isDark ? 'assets/tab_icons/taboptional-black.png' : 'assets/tab_icons/taboptional.png', '自选'),
      _TabData('assets/tab_icons/marketTrends.png', 'assets/tab_icons/marketTrends-a.png',
          isDark ? 'assets/tab_icons/marketTrends-black.png' : 'assets/tab_icons/marketTrends.png', '行情'),
      _TabData('assets/tab_icons/vip.png', 'assets/tab_icons/vip-a.png',
          isDark ? 'assets/tab_icons/vip-black.png' : 'assets/tab_icons/vip.png', '会员'),
      _TabData('assets/tab_icons/user.png', 'assets/tab_icons/user-a.png',
          isDark ? 'assets/tab_icons/user-black.png' : 'assets/tab_icons/user.png', '我的'),
    ];

    final barContent = Container(
      height: 50, // 100rpx
      padding: const EdgeInsets.symmetric(horizontal: 5), // 10rpx
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isActive = index == _currentIndex;
          final inactiveColor = isDark ? AppColors.tabInactiveDark : AppColors.tabInactiveColor;
          final inactiveOpacity = isDark ? 0.58 : 0.72;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onTabTap(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3), // 6rpx
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 21, height: 21, // 42rpx
                      child: Center(
                        // 源码 <image mode="aspectFit">：PNG 瞬时切换 + opacity 差异，无交叉淡入
                        child: Image.asset(
                          isActive ? tab.activeIcon : (isDark ? tab.darkIcon : tab.lightIcon),
                          width: 20, height: 20, // 40rpx
                          fit: BoxFit.contain,
                          opacity: AlwaysStoppedAnimation(isActive ? 1.0 : inactiveOpacity),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2), // 4rpx
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 10, // 20rpx
                        height: 1.0,
                        color: isActive
                            ? (isDark ? AppColors.tabActiveColor : AppColors.tabActiveColorLight)
                            : inactiveColor,
                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );

    // 浅色模式: 毛玻璃效果
    if (isDark) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.darkTabBg,
          border: Border(top: BorderSide(color: AppColors.tabBorderDark, width: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(71), blurRadius: 10, offset: const Offset(0, -1)),
          ],
        ),
        child: SafeArea(top: false, child: barContent),
      );
    }

    // 浅色模式: backdrop blur (匹配 uni-app blur(20px) ≈ sigma 10)
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tabBarBgLight, // rgba(255,255,255,0.95)
            border: Border(top: BorderSide(color: AppColors.tabBorderLight, width: 0.5)),
            boxShadow: [
              BoxShadow(color: const Color(0x0F000000), blurRadius: 10, offset: const Offset(0, -1)),
            ],
          ),
          child: SafeArea(top: false, child: barContent),
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    context.go(_routes[index]);
  }
}

class _TabData {
  final String lightIcon;
  final String activeIcon;
  final String darkIcon;
  final String label;
  const _TabData(this.lightIcon, this.activeIcon, this.darkIcon, this.label);
}
