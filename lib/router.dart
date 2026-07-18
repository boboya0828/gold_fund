import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_colors.dart';

import 'pages/home/home_page.dart';
import 'pages/position/position_page.dart';
import 'pages/position/position_details_page.dart';
import 'pages/optional/optional_page.dart';
import 'pages/optional/optional_search_page.dart';
import 'pages/optional/ledger_page.dart';
import 'pages/market/market_page.dart';
import 'pages/market/market_details_page.dart';
import 'pages/market/plate_ranking_page.dart';
import 'pages/member/member_page.dart';
import 'pages/member/morning_news_page.dart';
import 'pages/member/contrast_page.dart';
import 'pages/member/rising_chart_page.dart';
import 'pages/member/open_member_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/user/curve_page.dart';
import 'pages/user/profile_edit_page.dart';
import 'pages/user/share_page.dart';
import 'pages/user/settings_page.dart';
import 'pages/search/search_page.dart';
import 'pages/common/webview_page.dart';
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
            // 搜索
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SearchPage(),
              ),
            ),
            // 持仓详情
            GoRoute(
              path: '/position-details',
              pageBuilder: (context, state) {
                final symbolId = state.uri.queryParameters['symbolId'] ?? '';
                final assetType = int.tryParse(state.uri.queryParameters['assetType'] ?? '3') ?? 3;
                final assetId = int.tryParse(state.uri.queryParameters['assetId'] ?? '');
                return NoTransitionPage(
                  child: PositionDetailsPage(symbolId: symbolId, assetType: assetType, assetId: assetId),
                );
              },
            ),
            // 行情详情
            GoRoute(
              path: '/market-details',
              pageBuilder: (context, state) {
                final symbolId = state.uri.queryParameters['symbolId'] ?? '';
                final name = state.uri.queryParameters['name'];
                return NoTransitionPage(
                  child: MarketDetailsPage(symbolId: symbolId, name: name),
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
            // 自选搜索
            GoRoute(
              path: '/optional-search',
              pageBuilder: (context, state) => NoTransitionPage(
                child: OptionalSearchPage(
                  bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? '') ?? 0,
                ),
              ),
            ),
            // 分组管理
            GoRoute(
              path: '/ledger',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LedgerPage(),
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
              path: '/member/contrast',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ContrastPage(),
              ),
            ),
            GoRoute(
              path: '/member/rising-chart',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: RisingChartPage(),
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
              pageBuilder: (context, state) => const NoTransitionPage(
                child: UserCurvePage(),
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
