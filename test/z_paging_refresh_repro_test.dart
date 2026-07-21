import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/shared/widgets/z_paging_refresh.dart';

/// 「下拉回弹后 刷新成功 提示残留/遮挡」回归测试：
/// 固定表头 + 下方 ZPagingRefresh 列表（与 position_holding_table 结构一致）。
void main() {
  Future<void> pumpPage(WidgetTester tester, Completer<void> completer) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // 固定表头（对齐持仓页：表头在滚动区外）
              Container(
                height: 40,
                color: Colors.white,
                alignment: Alignment.center,
                child: const Text('当日收益 / 关联板块 / 持有收益'),
              ),
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: ZPagingRefresh(
                    isDark: false,
                    onRefresh: () => completer.future,
                    child: Column(
                      children: List.generate(
                        30,
                        (i) => Container(
                          height: 60,
                          color: Colors.white,
                          alignment: Alignment.centerLeft,
                          child: Text('基金 $i'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> dragRefresh(WidgetTester tester) async {
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    // 回弹进入「正在刷新...」（armed → refresh 依赖弹簧动画帧，轮询等待）
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('正在刷新...').evaluate().isNotEmpty) return;
    }
  }

  testWidgets('正常回弹：刷新完成后刷新头应收起', (tester) async {
    final completer = Completer<void>();
    await pumpPage(tester, completer);
    await dragRefresh(tester);

    expect(find.text('正在刷新...'), findsOneWidget);
    completer.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('刷新成功'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('刷新成功'), findsNothing, reason: '回弹结束后「刷新成功」必须收起');
  });

  testWidgets('卡在残余 overscroll（真机复现场景）：兜底收敛强制收起', (tester) async {
    final completer = Completer<void>();
    await pumpPage(tester, completer);
    await dragRefresh(tester);

    completer.complete();
    await tester.pump();

    // 模拟真机/Web 上的卡死：done 态回弹停在 -20px 不再动弹
    // （框架的 done→inactive 靠滚动活动驱动，没有活动就永远停在这里）
    tester.state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .correctPixels(-20);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('刷新成功'), findsOneWidget, reason: '复现：卡住时「刷新成功」露出半截');

    // 修复兜底：0.8s 后检测到残余负偏移 → 平滑归零 → 强制收起
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300)); // animateTo 200ms
    await tester.pumpAndSettle();

    expect(find.text('刷新成功'), findsNothing, reason: '兜底收敛后「刷新成功」必须消失');
    expect(find.text('继续下拉刷新'), findsNothing);
    expect(find.text('正在刷新...'), findsNothing);
  });
}
