import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yangji_zhushou/shared/widgets/z_paging_refresh.dart';

void main() {
  testWidgets('debug 刷新状态流转', (tester) async {
    final refreshCompleter = Completer<void>();
    var refreshCalled = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(height: 40, color: Colors.white),
              Expanded(
                child: ZPagingRefresh(
                  isDark: false,
                  onRefresh: () {
                    refreshCalled++;
                    return refreshCompleter.future;
                  },
                  child: Column(
                    children: List.generate(
                      30,
                      (i) => Container(height: 60, color: Colors.white, child: Text('基金 $i')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    void dump(String tag) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && (d.contains('刷新') || d.contains('下拉') || d.contains('松开')))
          .toList();
      debugPrint('[$tag] refreshCalled=$refreshCalled texts=$texts');
    }

    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    dump('拖动 200px 后');

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    dump('松手后');

    await tester.pump(const Duration(milliseconds: 500));
    dump('松手 500ms 后');

    refreshCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    dump('完成后 100ms');

    await tester.pump(const Duration(milliseconds: 500));
    dump('完成后 600ms');

    await tester.pump(const Duration(seconds: 2));
    dump('完成后 2.6s');

    await tester.pump(const Duration(seconds: 3));
    dump('完成后 5.6s');
  });
}
