import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/shared/widgets/z_paging_refresh.dart';

/// 「下拉回弹后刷新头残留/遮挡」回归测试（easy_refresh 实现）：
/// 固定表头 + 下方 ZPagingRefresh 列表（与 position_holding_table 结构一致）。
///
/// 语义锚点（与替换前一致）：
/// 1. 下拉超过阈值触发 onRefresh；
/// 2. 刷新完成后刷新头必须完全收起（offset 归零，不卡半截）。
void main() {
  Future<void> pumpPage(WidgetTester tester, Completer<void> completer,
      {void Function()? onCall}) {
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
                    onRefresh: () {
                      onCall?.call();
                      return completer.future;
                    },
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

  double pixels(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  Future<void> dragRefresh(WidgetTester tester) async {
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  Future<void> waitRefreshTriggered(
      WidgetTester tester, bool Function() triggered) async {
    for (var i = 0; i < 30 && !triggered(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('正常回弹：下拉触发刷新，完成后刷新头完全收起', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpPage(tester, completer, onCall: () => calls++);
    await dragRefresh(tester);

    // 松手后回弹进入刷新中（armed → processing 依赖弹簧动画帧，轮询等待）
    await waitRefreshTriggered(tester, () => calls > 0);
    expect(calls, 1, reason: '下拉超过 50px 阈值必须触发一次刷新');

    completer.complete();
    await tester.pump();
    // 完成态（success 对勾）→ 消失动画 → 收起
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      pixels(tester),
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '刷新完成后刷新头必须完全收起，不允许残留 overscroll',
    );
  });

  testWidgets('处理中偏移被扰动：完成后仍收敛归零，不卡半截', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpPage(tester, completer, onCall: () => calls++);
    await dragRefresh(tester);
    await waitRefreshTriggered(tester, () => calls > 0);
    expect(calls, 1);

    // 模拟真机/Web 上的异常：刷新处理中位置被外力卡在残余 overscroll
    tester.state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .correctPixels(-20);
    await tester.pump(const Duration(milliseconds: 100));

    completer.complete();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      pixels(tester),
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '即使处理中偏移被扰动，完成后也必须收敛归零，不卡半截',
    );
  });

  testWidgets('未达到阈值不触发刷新', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpPage(tester, completer, onCall: () => calls++);

    // 只下拉 30px（< 50px 阈值）后松手
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, 0, reason: '未达到阈值不允许触发刷新');
    completer.complete();
  });
}
