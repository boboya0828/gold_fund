import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart'
    show IndexCarouselItem;
import 'package:yangji_zhushou/pages/position/widgets/position_index_carousel_sheet.dart';

/// 指数详情 sheet 冒烟测试：打开后半屏面板渲染市场 tabs，接口失败静默不崩
void main() {
  testWidgets('sheet 打开渲染五个市场 tab，接口失败静默', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => PositionIndexCarouselSheet.show(
            context,
            item: const IndexCarouselItem(
              symbolId: 1031413,
              name: '沪深300',
              code: '000300',
              marketCode: 'CN',
              latestPrice: 4000.5,
              chgRate: 0.5,
            ),
            isDark: false,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final label in ['A股', '港股', '美股', '全球', '黄金']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('板块排行'), findsOneWidget);
    // 测试环境接口不可达：列表加载失败静默，行情头回落占位 '--'
    expect(find.text('--'), findsWidgets);

    // Dio 超时定时器消化（接口在测试环境不可达，失败静默）
    await tester.pump(const Duration(seconds: 16));
    expect(tester.takeException(), isNull);
  });
}
