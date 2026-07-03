import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yangji_zhushou/app.dart';

void main() {
  testWidgets('App starts with ProviderScope and renders home tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: YangJiApp(),
      ),
    );

    // 首页应该显示 "养基助手" 标题
    expect(find.text('养基助手'), findsOneWidget);

    // 首页应该显示 "我的资产" 标签
    expect(find.text('我的资产'), findsOneWidget);

    // 应该显示 "基金列表" 标签
    expect(find.text('基金列表'), findsOneWidget);
  });
}
