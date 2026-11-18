import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_index_carousel.dart';
import 'package:yangji_zhushou/pages/position/widgets/position_index_carousel_sheet.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart'
    show IndexCarouselItem;

void main() {
  testWidgets('tap carousel row opens sheet', (tester) async {
    IndexCarouselItem? selected;
    const item = IndexCarouselItem(
      symbolId: 1,
      name: '上证指数',
      code: '000001',
      latestPrice: 3000.0,
      changeAmount: 10.0,
      chgRate: 0.33,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PositionIndexCarousel(
                  items: const [item],
                  mode: 1,
                  isDark: false,
                  onSelect: (i) {
                    selected = i;
                    PositionIndexCarouselSheet.show(
                      tester.element(find.byType(Scaffold)),
                      item: i,
                      isDark: false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('上证指数'));
    await tester.pump();
    expect(selected, isNotNull, reason: 'onSelect 未被触发');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PositionIndexCarouselSheet), findsOneWidget,
        reason: 'sheet 未弹出');
  });
}
