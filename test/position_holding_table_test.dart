import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_asset_card.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_holding_table.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_nav_header.dart';

void main() {
  PositionState positionState({
    int assetVisible = 0,
    TableShowMode tableMode = TableShowMode.normal,
  }) {
    return PositionState(
      isLoggedIn: true,
      tableMode: tableMode,
      totalMarketValue: 9988.66,
      totalDayProfit: 88.12,
      assetVisible: assetVisible,
      items: [
        PositionItem.fromJson({
          'assetId': 1,
          'symbolId': 2,
          'assetType': 3,
          'shortName': '测试基金',
          'marketValue': 1234.56,
          'dayProfit': 12.34,
          'dayChangeRatio': 1.23,
          'holdProfit': 56.78,
          'holdChangeRatio': 4.56,
          'isLatestNav': true,
          'indicatorList': [
            {'name': '半导体', 'changeRatio': 2.34},
          ],
        }),
      ],
    );
  }

  testWidgets('position table renders original uniapp holding list labels', (
    tester,
  ) async {
    final state = positionState();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PositionHoldingTable(
              state: state,
              isDark: false,
              selectedIndex: -1,
              onSelect: (_) {},
              onRowTap: () {},
              onSortToggle: () {},
              onSortManage: () {},
              onSyncTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('当日收益'), findsOneWidget);
    expect(find.text('关联板块'), findsOneWidget);
    expect(find.text('持有收益'), findsOneWidget);
    expect(find.text('测试基金'), findsOneWidget);
    expect(find.text('￥1234.56'), findsOneWidget);
    expect(find.text('已更新'), findsOneWidget);
    expect(find.text('同步持仓'), findsOneWidget);
  });

  testWidgets('position holdings preserve original uniapp vertical rhythm', (
    tester,
  ) async {
    final state = positionState();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PositionAssetCard(state: state, isDark: false, onEyeTap: () {}),
                PositionHoldingTable(
                  state: state,
                  isDark: false,
                  selectedIndex: -1,
                  onSelect: (_) {},
                  onRowTap: () {},
                  onSortToggle: () {},
                  onSortManage: () {},
                  onSyncTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final assetRect = tester.getRect(
      find.byKey(const Key('position-asset-card')),
    );
    final headerRect = tester.getRect(
      find.byKey(const Key('position-table-header')),
    );
    final rowRect = tester.getRect(
      find.byKey(const Key('position-holding-row-0')),
    );

    expect(assetRect.height, 65);
    expect(headerRect.top, assetRect.bottom);
    expect(rowRect.height, 50);
  });

  testWidgets('position book tabs keep indicator space for every tab', (
    tester,
  ) async {
    const state = PositionState(
      isLoggedIn: true,
      books: [BookItem(bookId: 1, bookName: '成长账本')],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PositionNavHeader(
              state: state,
              isDark: false,
              topPadding: 0,
              onSearchTap: () {},
              onMenuTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('position-nav-background')), findsOneWidget);
    expect(find.byKey(const Key('position-fund-group-image')), findsOneWidget);

    final activeIndicator = tester.getSize(
      find.byKey(const Key('position-book-tab-indicator-0')),
    );
    final inactiveIndicator = tester.getSize(
      find.byKey(const Key('position-book-tab-indicator-1')),
    );

    expect(activeIndicator.height, 4);
    expect(inactiveIndicator.height, 4);
  });

  testWidgets('position nav hides asset errors when background is missing', (
    tester,
  ) async {
    const state = PositionState(isLoggedIn: true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PositionNavHeader(
              state: state,
              isDark: false,
              topPadding: 0,
              backgroundAsset: 'assets/images/img/missing-position-bg.png',
              onSearchTap: () {},
              onMenuTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('position-nav-background')), findsOneWidget);
    expect(find.textContaining('Unable to load asset'), findsNothing);
  });

  test('position item reads original uniapp indicators field', () {
    final item = PositionItem.fromJson({
      'shortName': 'Fund',
      'indicators': [
        {'name': 'Robot', 'changeRatio': 1.23},
      ],
    });

    expect(item.firstIndicator?.name, 'Robot');
    expect(item.firstIndicator?.changeRatio, 1.23);
  });

  testWidgets('position table header uses original bars mode icon', (
    tester,
  ) async {
    final state = positionState(tableMode: TableShowMode.normal);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PositionHoldingTable(
              state: state,
              isDark: false,
              selectedIndex: -1,
              onSelect: (_) {},
              onRowTap: () {},
              onSortToggle: () {},
              onSortManage: () {},
              onSyncTap: () {},
            ),
          ),
        ),
      ),
    );

    final modeIcon = tester.widget<Icon>(
      find.byKey(const Key('position-header-mode-icon')),
    );

    expect(modeIcon.icon, Icons.menu);
    expect(find.byIcon(Icons.view_agenda), findsNothing);
  });

  testWidgets('position header columns align with holding row columns', (
    tester,
  ) async {
    final state = positionState();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PositionHoldingTable(
              state: state,
              isDark: false,
              selectedIndex: -1,
              onSelect: (_) {},
              onRowTap: () {},
              onSortToggle: () {},
              onSortManage: () {},
              onSyncTap: () {},
            ),
          ),
        ),
      ),
    );

    double leftOf(String key) => tester.getTopLeft(find.byKey(Key(key))).dx;

    expect(
      leftOf('position-header-day-profit'),
      closeTo(leftOf('position-row-day-profit-0'), 0.1),
    );
    expect(
      leftOf('position-header-indicator'),
      closeTo(leftOf('position-row-indicator-0'), 0.1),
    );
    expect(
      leftOf('position-header-hold-profit'),
      closeTo(leftOf('position-row-hold-profit-0'), 0.1),
    );
  });
}
