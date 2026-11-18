import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yangji_zhushou/pages/position/position_details_page.dart';

/// 持仓详情页关键判定分支冒烟测试：
/// - assetType=7 贵金属初始化
/// - bookId=-1 / assetId=-1 汇总视图初始化
/// - 无 symbolId 直接结束骨架
/// - item JSON 兜底解析
/// （真实接口请求可能在测试环境超时，pump 到 Dio 超时后结束，验证页面结构与状态机不崩）
void main() {
  Future<void> settle(tester) async {
    await tester.pump();
    // Dio connectTimeout=15s：推进 fake clock 让超时定时器消化（IO 实际失败也在此期间完成）
    await tester.pump(const Duration(seconds: 16));
  }

  testWidgets('assetType=7（贵金属）初始化不崩溃', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: PositionDetailsPage(symbolId: '1', assetType: 7),
      ),
    ));
    await settle(tester);
    expect(find.byType(PositionDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookId=-1 / assetId=-1（汇总视图）初始化不崩溃', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: PositionDetailsPage(symbolId: '1', bookId: -1, assetId: -1),
      ),
    ));
    await settle(tester);
    expect(find.byType(PositionDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无 symbolId 直接结束骨架不崩溃', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: PositionDetailsPage(symbolId: ''),
      ),
    ));
    await tester.pump();
    expect(find.byType(PositionDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item JSON 兜底解析（含 symbolId/assetId/bookId）不崩溃', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: PositionDetailsPage(
          symbolId: '',
          itemJson: '{"symbolId":"110022","assetId":"123","bookId":7}',
        ),
      ),
    ));
    await settle(tester);
    expect(find.byType(PositionDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
