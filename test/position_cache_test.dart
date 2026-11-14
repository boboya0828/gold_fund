import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yangji_zhushou/features/position/providers/position_provider.dart';

/// 持仓首页缓存（position_page_cache_v1）测试：
/// save→restore 回环、游客不写、tabIndex 恢复规则（含游客强制「全部」与可见性 ±1 调整）
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('position_cache_test');
    Hive.init(tempDir.path);
    await Hive.openBox('positionCache');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('positionCache').clear();
  });

  PositionItem sampleItem() => PositionItem.fromJson({
        'assetId': 1,
        'symbolId': 2,
        'assetType': 3,
        'shortName': '缓存测试基金',
        'marketValue': 1234.56,
        'dayProfit': 12.34,
        'dayChangeRatio': 1.23,
        'holdProfit': 56.78,
        'holdChangeRatio': 4.56,
        'symbolCode': '012345',
      });

  void mockLoggedIn() {
    SharedPreferences.setMockInitialValues({
      'token': 'token-abc',
      'userInfo': '{"userId": 42}',
    });
  }

  test('save→restore 回环：账本/tab/持仓/统计/日期完整恢复', () async {
    mockLoggedIn();
    final n1 = PositionNotifier();
    n1.state = n1.state.copyWith(
      isLoggedIn: true,
      books: const [BookItem(bookId: 7, bookName: '成长账本')],
      tabIndex: 1, // 「全部」=0，第一个账本=1
      items: [sampleItem()],
      totalMarketValue: 9988.66,
      totalDayProfit: 88.12,
      totalDayChangeRatio: 0.88,
      curTradeDate: '2026-11-13',
      latestNavDate: '2026-11-12',
      extendedCurTradeDate: '2026-11-11',
    );
    await n1.saveCacheNow();

    final n2 = PositionNotifier();
    final hit = await n2.restorePositionCache();
    expect(hit, isTrue, reason: '有缓存应命中');
    expect(n2.state.books.map((b) => b.bookName), ['成长账本']);
    expect(n2.state.tabIndex, 1);
    expect(n2.state.items.single.shortName, '缓存测试基金');
    expect(n2.state.items.single.marketValue, 1234.56);
    expect(n2.state.totalMarketValue, 9988.66);
    expect(n2.state.totalDayProfit, 88.12);
    expect(n2.state.curTradeDate, '2026-11-13');
    expect(n2.state.latestNavDate, '2026-11-12');
    expect(n2.state.extendedCurTradeDate, '2026-11-11');

    // 恢复一次守卫：同 key 二次调用直接跳过
    n2.state = n2.state.copyWith(tabIndex: 0);
    final hit2 = await n2.restorePositionCache();
    expect(hit2, isFalse);
    expect(n2.state.tabIndex, 0, reason: '守卫命中后不应再被缓存覆盖');
  });

  test('游客不写缓存（防串号）', () async {
    SharedPreferences.setMockInitialValues({
      'token': 'token-abc',
      'userInfo': '{"userId": 42}',
    });
    final n1 = PositionNotifier();
    n1.state = n1.state.copyWith(
      isLoggedIn: true,
      books: const [BookItem(bookId: 7, bookName: '成长账本')],
      tabIndex: 1,
      items: [sampleItem()],
    );
    await n1.saveCacheNow();
    expect(Hive.box('positionCache').keys, isNotEmpty);

    // 清空 token（退出登录）后再保存：不应写入任何新缓存
    SharedPreferences.setMockInitialValues({});
    final box = Hive.box('positionCache');
    final before = Map.fromEntries(box.keys.map((k) => MapEntry(k, box.get(k))));
    final n2 = PositionNotifier();
    n2.state = n2.state.copyWith(
      isLoggedIn: false,
      items: [sampleItem()],
    );
    await n2.saveCacheNow();
    final afterKeys = box.keys.toList();
    expect(afterKeys.length, before.length, reason: '游客保存不产生新键');
    // guest 桶也不应出现
    expect(afterKeys.any((k) => '$k'.contains('guest')), isFalse);
  });

  test('游客恢复强制落「全部」tab（忽略缓存的账户汇总 tab）', () async {
    // 预写登录态缓存：1 个账本 + allBookVisible → overviewTabIndex=2，缓存 tab 停在汇总
    mockLoggedIn();
    final n1 = PositionNotifier();
    n1.state = n1.state.copyWith(
      isLoggedIn: true,
      books: const [BookItem(bookId: 7, bookName: '成长账本')],
      tabIndex: 2, // 账户汇总 tab
      items: [sampleItem()],
    );
    await n1.saveCacheNow();

    SharedPreferences.setMockInitialValues({}); // 游客
    final n2 = PositionNotifier();
    await n2.restorePositionCache();
    expect(n2.state.tabIndex, 0, reason: '游客强制落「全部」tab');
  });

  test('allBookVisible 变化时 tabIndex ±1 调整', () async {
    // 缓存时 allBookVisible=true，tab=第一个账本(1)
    SharedPreferences.setMockInitialValues({
      'token': 'token-abc',
      'userInfo': '{"userId": 42}',
      'positionAllBookVisible': true,
    });
    final n1 = PositionNotifier();
    n1.state = n1.state.copyWith(
      isLoggedIn: true,
      books: const [BookItem(bookId: 7, bookName: '成长账本')],
      tabIndex: 1,
      items: [sampleItem()],
    );
    await n1.saveCacheNow();

    // 关闭「全部」tab 后恢复：tabIndex 应 -1
    SharedPreferences.setMockInitialValues({
      'token': 'token-abc',
      'userInfo': '{"userId": 42}',
      'positionAllBookVisible': false,
    });
    final n2 = PositionNotifier();
    await n2.restorePositionCache();
    expect(n2.state.tabIndex, 0, reason: '缓存 visible=true → 当前 false，索引 -1');
  });

  test('无缓存初始化空态（books/tabIndex 归零，「全部」可渲染）', () async {
    mockLoggedIn();
    final n = PositionNotifier();
    final hit = await n.restorePositionCache();
    expect(hit, isFalse);
    expect(n.state.books, isEmpty);
    expect(n.state.tabIndex, 0);
    expect(n.state.items, isEmpty);
    expect(n.state.bookNames, ['全部'], reason: '无缓存也要初始化出「全部」tab');
  });
}
