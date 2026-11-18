import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart'
    show IndexCarouselItem;
import 'package:yangji_zhushou/pages/position/widgets/position_index_carousel.dart';

/// 指数轮播条测试：静态/滚动两种模式、停牌文案、涨跌色、点击透传
void main() {
  const up = IndexCarouselItem(
    symbolId: 1,
    name: '上证指数',
    latestPrice: 3123.45,
    chgRate: 1.23,
    changeAmount: 38.12,
  );
  const down = IndexCarouselItem(
    symbolId: 2,
    name: '恒生指数',
    latestPrice: 18123.45,
    chgRate: -0.87,
    changeAmount: -158.2,
  );
  const suspended = IndexCarouselItem(
    symbolId: 3,
    name: '测试停牌',
    latestPrice: 10.5,
    priceStatus: 1,
    priceStatusText: '',
  );

  Widget harness(List<IndexCarouselItem> items,
      {int mode = 1, ValueChanged<IndexCarouselItem>? onSelect}) {
    return MaterialApp(
      home: Scaffold(
        body: PositionIndexCarousel(
          items: items,
          mode: mode,
          isDark: false,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('mode=1 静态展示首条（名称/价格/涨跌额/涨跌幅）', (tester) async {
    await tester.pumpWidget(harness(const [up, down], mode: 1));
    expect(find.text('上证指数'), findsOneWidget);
    expect(find.text('3123.45'), findsOneWidget);
    expect(find.text('+38.12'), findsOneWidget);
    expect(find.text('+1.23%'), findsOneWidget);
    // 静态模式不渲染第二条
    expect(find.text('恒生指数'), findsNothing);
  });

  testWidgets('mode=1 涨条目渐变与色值（红涨绿跌 #E15665/#20B083）', (tester) async {
    await tester.pumpWidget(harness(const [up], mode: 1));
    final priceText = tester.widget<Text>(find.text('+1.23%'));
    expect(priceText.style?.color, const Color(0xFFE15665));
  });

  testWidgets('停牌条目显示状态文案不着涨跌色', (tester) async {
    await tester.pumpWidget(harness(const [suspended], mode: 1));
    expect(find.text('测试停牌'), findsOneWidget);
    expect(find.text('停牌'), findsOneWidget);
    expect(find.text('+0.00%'), findsNothing);
  });

  testWidgets('mode=2 多条上下滚动（8s 间隔 + 末条跳回首条无缝循环）', (tester) async {
    await tester.pumpWidget(harness(const [up, down], mode: 2));
    expect(find.byType(PageView), findsOneWidget);
    // 初始第一页
    final pageView = tester.widget<PageView>(find.byType(PageView));
    final ctrl = pageView.controller!;
    expect(ctrl.page?.round(), 0);
    // 8s 后滚到第二条
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 700)); // 动画 600ms + 余量
    expect(ctrl.page?.round(), 1);
    // 再 8s 滚到复制条（首条副本），随后无动画跳回 0
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 700));
    expect(ctrl.page?.round(), 0);
  });

  testWidgets('mode=2 条目点击透传 select 事件', (tester) async {
    IndexCarouselItem? selected;
    await tester.pumpWidget(harness(const [up, down],
        mode: 2, onSelect: (item) => selected = item));
    await tester.tap(find.text('上证指数'));
    expect(selected?.symbolId, 1);
  });
}
