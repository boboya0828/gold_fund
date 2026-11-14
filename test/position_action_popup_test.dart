import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_action_popup.dart';

void main() {
  PositionState stateWith({int assetType = 3}) {
    return PositionState(
      isLoggedIn: true,
      tabIndex: 0,
      items: [
        PositionItem.fromJson({
          'assetId': 1,
          'symbolId': 2,
          'assetType': assetType,
          'shortName': '测试基金A',
          'marketValue': 1234.56,
          'symbolCode': '012345',
          'uniqueSymbol': 'FUND:012345',
        }),
      ],
    );
  }

  Widget harness(PositionState state) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          PositionActionPopup(
            state: state,
            selectedIndex: 0,
            rowOffset: const Offset(0, 200),
            rowHeight: 55,
            screenWidth: 800,
            onClose: () {},
            onEdit: () {},
            onBatchEdit: () {},
            onBatchAdjust: () {},
            onPinTop: () {},
            onMoveGroup: () {},
            onDelete: (_) {},
          ),
        ]),
      ),
    );
  }

  testWidgets('基金行长按弹框：8 个操作项（含基金笔记/基金反馈）', (tester) async {
    await tester.pumpWidget(harness(stateWith()));

    // 标题 = 基金短名（.popup-title）
    expect(find.text('测试基金A'), findsOneWidget);

    // 8 个操作项 1:1 popupActionList
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('修改持仓'), findsOneWidget);
    expect(find.text('批量编辑'), findsOneWidget);
    expect(find.text('批量加减仓'), findsOneWidget);
    expect(find.text('移动分组'), findsOneWidget);
    expect(find.text('基金笔记'), findsOneWidget);
    expect(find.text('基金反馈'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    // 4 列网格：8 项 = 2 行，行容器应为 2 个
    final gridRows = tester
        .widgetList<Row>(find.byType(Row))
        .where((r) => r.children.length == 7) // 4 cell + 3 间隔
        .length;
    expect(gridRows, 2, reason: '8 个操作项应排成 2 行 × 4 列');

    // 方向箭头（CustomPaint 三角形）
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('贵金属行长按弹框：6 个操作项（无基金笔记/基金反馈）', (tester) async {
    await tester.pumpWidget(harness(stateWith(assetType: 7)));

    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('移动分组'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('基金笔记'), findsNothing);
    expect(find.text('基金反馈'), findsNothing);
  });
}
