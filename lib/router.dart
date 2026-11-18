import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_icons.dart';
import 'core/utils/screen_adapt.dart';

import 'pages/home/home_page.dart';
import 'pages/position/position_page.dart';
import 'pages/position/position_details_page.dart';
import 'pages/position/position_sort_page.dart';
import 'pages/position/position_search_page.dart';
import 'pages/position/fund_note_page.dart';
import 'pages/position/batch_adjust_page.dart';
import 'pages/position/trading_record_page.dart';
import 'pages/optional/optional_page.dart';
import 'pages/optional/optional_search_page.dart';
import 'pages/optional/ledger_page.dart';
import 'pages/optional/widgets/ledger_book_api.dart';
import 'pages/market/market_page.dart';
import 'pages/market/dark_market_page.dart';
import 'pages/noblemetal/noblemetal_page.dart';
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
import 'pages/user/feedback_form_page.dart';
import 'pages/common/webview_page.dart';
import 'pages/common/privacy_auth_page.dart';
import 'pages/common/guide_page.dart';
import 'pages/common/simple_placeholder_page.dart';
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
///   /position       → 持仓 (Tab 0, 游客可看)
///   /optional       → 自选 (Tab 1, 游客可看)
///   /noblemetal     → 攒金 (Tab 2)
///   /market         → 行情 (Tab 3)
///   /dark-market    → 暗盘 (Tab 4)
///   /profile        → 我的 (Tab 5)
///   /home /member   → 保留页面但不在底部 tab（对齐 uni-app tabBar 配置）
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  /// 子页面统一转场：右滑推入（对齐 uni-app navigateTo 观感）
  /// 配合 parentNavigatorKey: _rootNavigatorKey 在 root navigator 上全屏压栈
  static Page<void> _slidePage({required Widget child}) => CustomTransitionPage<void>(
        child: child,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      );

  // 单例，避免重复创建导致 GlobalKey 冲突
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/position',
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

        // ===== 子页面（root navigator 全屏压栈 + 右滑转场，不显示 TabBar）=====
        // 持仓详情
        GoRoute(
          path: '/position-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            final symbolId = q['symbolId'] ?? '';
            final assetType = int.tryParse(q['assetType'] ?? '3') ?? 3;
            final assetId = int.tryParse(q['assetId'] ?? '');
            return _slidePage(
              child: PositionDetailsPage(
                symbolId: symbolId,
                assetType: assetType,
                assetId: assetId,
                bookId: int.tryParse(q['bookId'] ?? ''),
                fromAllBooks: q['fromAllBooks'] == '1' || q['fromAllBooks'] == 'true',
                switchToken: q['switchToken'] ?? '',
                itemJson: q['item'] ?? '',
              ),
            );
          },
        ),
        // 持仓排序管理
        GoRoute(
          path: '/position-sort',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: PositionSortPage(
              bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? ''),
            ),
          ),
        ),
        // 持仓搜索 (from=trading-record 时 pop 返回选中基金)
        GoRoute(
          path: '/position-search',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: PositionSearchPage(
              from: state.uri.queryParameters['from'] ?? '',
              bookId: state.uri.queryParameters['bookId'] ?? '',
            ),
          ),
        ),
        // 批量加减仓
        GoRoute(
          path: '/batch-adjust',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: FundSettingsPage(
              symbolId: state.uri.queryParameters['symbolId'],
              assetId: state.uri.queryParameters['assetId'],
            ),
          ),
        ),
        // 历史净值
        GoRoute(
          path: '/fund/listed-net-value',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: ListedNetValuePage(
              symbolId: int.tryParse(
                  state.uri.queryParameters['symbolId'] ?? ''),
            ),
          ),
        ),
        // 阶段收益
        GoRoute(
          path: '/fund/stage-revenue',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: StageRevenuePage(
              symbolId: int.tryParse(
                  state.uri.queryParameters['symbolId'] ?? ''),
            ),
          ),
        ),
        // 基金交易记录
        GoRoute(
          path: '/fund/trading-record',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: MassUploadPage(
              bookId: state.uri.queryParameters['bookId'],
            ),
          ),
        ),
        GoRoute(
          path: '/fund/upload/add-records',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: OcrResultPage(
              bookId: state.uri.queryParameters['bookId'],
              data: state.uri.queryParameters['data'],
            ),
          ),
        ),
        // 行情详情
        GoRoute(
          path: '/market-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            final symbolId = q['symbolId'] ?? '';
            final name = q['name'];
            return _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: PlateRankingPage(),
          ),
        ),
        // 板块数据
        GoRoute(
          path: '/plate-data',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: PlateDataPage(),
          ),
        ),
        // 精选榜单 (tab=hot/selected/holding/rise/streak)
        GoRoute(
          path: '/selected-list',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SelectedListPage(
              initialTab: state.uri.queryParameters['tab'],
            ),
          ),
        ),
        // 自选搜索
        GoRoute(
          path: '/optional-search',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: OptionalSearchPage(
              bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? '') ?? 0,
            ),
          ),
        ),
        // 分组/账本管理 (type=asset 时为持仓账本)
        GoRoute(
          path: '/ledger',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: MorningNewsPage(),
          ),
        ),
        GoRoute(
          path: '/member/closing-news',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: ClosingNewsPage(),
          ),
        ),
        GoRoute(
          path: '/member/details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: MemberDetailsPage(
              type: state.uri.queryParameters['type'] ?? 'morning',
              id: state.uri.queryParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/member/contrast',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: ContrastPage(),
          ),
        ),
        GoRoute(
          path: '/member/rising-chart',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: RisingChartPage(
              period: state.uri.queryParameters['period'] ?? 'today',
              detailId: state.uri.queryParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/member/open-member',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: OpenMemberPage(),
          ),
        ),
        // 用户子页
        GoRoute(
          path: '/user/curve',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: UserCurvePage(
              bookId: state.uri.queryParameters['bookId'],
            ),
          ),
        ),
        GoRoute(
          path: '/user/distribution',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: DistributionPage(
              bookId: state.uri.queryParameters['bookId'],
              type: state.uri.queryParameters['type'],
            ),
          ),
        ),
        GoRoute(
          path: '/user/profit-detail',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: ProfitDetailPage(
              bookId: state.uri.queryParameters['bookId'],
              date: state.uri.queryParameters['date'],
            ),
          ),
        ),
        GoRoute(
          path: '/user/nickname',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: NicknamePage(),
          ),
        ),
        GoRoute(
          path: '/user/bound-phone',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: BoundPhonePage(),
          ),
        ),
        GoRoute(
          path: '/user/skin',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SkinPage(),
          ),
        ),
        GoRoute(
          path: '/user/profile',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: ProfileEditPage(),
          ),
        ),
        GoRoute(
          path: '/user/share',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SharePage(),
          ),
        ),
        GoRoute(
          path: '/user/settings',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SettingsPage(),
          ),
        ),
        // 基金笔记（占位页，入口：持仓长按弹框）
        GoRoute(
          path: '/fund-note',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: FundNotePage(
              symbolId: state.uri.queryParameters['symbolId'] ?? '',
              symbolCode: state.uri.queryParameters['symbolCode'] ?? '',
              fundName: state.uri.queryParameters['fundName'] ?? '',
            ),
          ),
        ),
        // 意见反馈（占位页，入口：持仓长按弹框「基金反馈」type=sector）
        GoRoute(
          path: '/user/feedback-form',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: FeedbackFormPage(
              type: state.uri.queryParameters['type'] ?? '',
              fundCode: state.uri.queryParameters['fundCode'] ?? '',
              fundName: state.uri.queryParameters['fundName'] ?? '',
            ),
          ),
        ),
        // ===== 持仓详情页依赖的未移植子页（占位 + TODO）=====
        // 资金流向详情 (uni-app pages/index/fund/fund-flow-details) TODO 移植
        GoRoute(
          path: '/fund/fund-flow-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(title: '资金详情'),
          ),
        ),
        // 基金收益排行 (uni-app pages/market/sub/fund-return-ranking) TODO 移植
        GoRoute(
          path: '/fund/fund-return-ranking',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(
              title: '基金收益排行',
              message: '收益排行页面建设中',
            ),
          ),
        ),
        // 个股详情 (uni-app pages/market/sub/stock-detail) TODO 移植
        GoRoute(
          path: '/market/stock-detail',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(
              title: state.uri.queryParameters['name']?.isNotEmpty == true
                  ? state.uri.queryParameters['name']!
                  : '个股详情',
            ),
          ),
        ),
        // 诊基报告 (uni-app pages/market/sub/fund-analysis-demo) TODO 移植
        GoRoute(
          path: '/market/fund-analysis',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(title: '诊基报告', message: 'AI 诊基报告建设中'),
          ),
        ),
        // 积分中心 (uni-app pages/user/sub/points) TODO 移植
        GoRoute(
          path: '/user/points',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(title: '积分中心'),
          ),
        ),
        // 指数设置 (uni-app pages/positionv1/sub/index-settings) TODO 移植
        GoRoute(
          path: '/position/index-settings',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(title: '指数设置'),
          ),
        ),
        // 板块详情 (uni-app pages/market/sub/sector-details) TODO 移植
        GoRoute(
          path: '/market/sector-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: SimplePlaceholderPage(
              title: state.uri.queryParameters['name']?.isNotEmpty == true
                  ? state.uri.queryParameters['name']!
                  : '板块详情',
            ),
          ),
        ),
        // 公关页面
        GoRoute(
          path: '/privacy',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: WebViewPage(title: '隐私政策'),
          ),
        ),
        GoRoute(
          path: '/agreement',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _slidePage(
            child: WebViewPage(title: '用户协议'),
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
            // 持仓（游客可看，对齐 uni-app positionv1 的 hasToken 处理）
            GoRoute(
              path: '/position',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PositionPage(),
              ),
            ),
            // 自选（游客可看）
            GoRoute(
              path: '/optional',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: OptionalPage(),
              ),
            ),
            // 攒金
            GoRoute(
              path: '/noblemetal',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NobleMetalPage(),
              ),
            ),
            // 行情
            GoRoute(
              path: '/market',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MarketPage(),
              ),
            ),
            // 暗盘
            GoRoute(
              path: '/dark-market',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DarkMarketPage(),
              ),
            ),
            // 会员（保留页面，不在底部 tab）
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

          ],
        ),
      ],
    );
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

  // 对齐 uni-app CustomTabBar.vue rawTabList（H5/App 端）：
  // 持仓 / 自选 / 攒金 / 行情 / 暗盘 / 我的（首页、会员不在 tab 中）
  static const _routes = [
    '/position', '/optional', '/noblemetal', '/market', '/dark-market', '/profile'
  ];

  @override
  Widget build(BuildContext context) {
    // 依赖 MediaQuery：web 拖窗口/旋屏时触发 SA 尺寸重建
    MediaQuery.sizeOf(context);
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
    // 1:1 uni-app CustomTabBar.vue：持仓/自选/攒金/行情/暗盘(iconfont)/我的
    final tabs = [
      _TabData('assets/tab_icons/position.png', 'assets/tab_icons/position-a.png',
          isDark ? 'assets/tab_icons/position-black.png' : 'assets/tab_icons/position.png', '持仓'),
      _TabData('assets/tab_icons/taboptional.png', 'assets/tab_icons/tab_optional.png',
          isDark ? 'assets/tab_icons/taboptional-black.png' : 'assets/tab_icons/taboptional.png', '自选'),
      _TabData('assets/tab_icons/noblemetal.png', 'assets/tab_icons/noblemetal-a.png',
          isDark ? 'assets/tab_icons/noblemetal-black.png' : 'assets/tab_icons/noblemetal.png', '攒金'),
      _TabData('assets/tab_icons/marketTrends.png', 'assets/tab_icons/marketTrends-a.png',
          isDark ? 'assets/tab_icons/marketTrends-black.png' : 'assets/tab_icons/marketTrends.png', '行情'),
      const _TabData.iconfont(AppIcons.meigu, '暗盘'),
      _TabData('assets/tab_icons/user.png', 'assets/tab_icons/user-a.png',
          isDark ? 'assets/tab_icons/user-black.png' : 'assets/tab_icons/user.png', '我的'),
    ];

    final barContent = Container(
      height: 50.sx, // 100rpx
      padding: EdgeInsets.symmetric(horizontal: 5.sx), // 10rpx
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
                padding: EdgeInsets.symmetric(vertical: 3.sx), // 6rpx
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 21.sx, height: 21.sx, // 42rpx
                      child: Center(
                        // 源码 <image mode="aspectFit">：PNG 瞬时切换 + opacity 差异，无交叉淡入
                        // iconfont 项（暗盘）：源码 .tab-iconfont color #333 / 深色 #A7ADB8，
                        // opacity 恒 0.72（深色不降级），激活 #E60012 / 深色 #E05665
                        child: tab.icon != null
                            ? Icon(
                                tab.icon,
                                size: 20.sx, // 40rpx
                                color: isActive
                                    ? (isDark ? AppColors.tabActiveColor : AppColors.tabActiveColorLight)
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightText)
                                        .withAlpha(184), // 0.72
                              )
                            : Image.asset(
                                isActive ? tab.activeIcon! : (isDark ? tab.darkIcon! : tab.lightIcon!),
                                width: 20.sx, height: 20.sx, // 40rpx
                                fit: BoxFit.contain,
                                opacity: AlwaysStoppedAnimation(isActive ? 1.0 : inactiveOpacity),
                              ),
                      ),
                    ),
                    SizedBox(height: 2.sx), // 4rpx
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 10.sx, // 20rpx
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
  final String? lightIcon;
  final String? activeIcon;
  final String? darkIcon;
  final IconData? icon; // iconfont 图标（优先于 png）
  final String label;
  const _TabData(this.lightIcon, this.activeIcon, this.darkIcon, this.label)
      : icon = null;
  const _TabData.iconfont(this.icon, this.label)
      : lightIcon = null,
        activeIcon = null,
        darkIcon = null;
}
