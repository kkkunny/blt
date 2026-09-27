import 'package:blt/storages/search_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('新增关键词排在最前', () async {
    await SearchHistory.add('关键词A');
    await SearchHistory.add('关键词B');

    expect(await SearchHistory.load(), ['关键词B', '关键词A']);
  });

  test('重复关键词提到最前且不产生重复', () async {
    await SearchHistory.add('A');
    await SearchHistory.add('B');
    await SearchHistory.add('A');

    expect(await SearchHistory.load(), ['A', 'B']);
  });

  test('空白关键词不入库', () async {
    await SearchHistory.add('   ');
    await SearchHistory.add('');

    expect(await SearchHistory.load(), isEmpty);
  });

  test('超过上限时丢弃最旧的', () async {
    for (var i = 0; i < SearchHistory.maxItems + 3; i++) {
      await SearchHistory.add('词$i');
    }

    final history = await SearchHistory.load();
    expect(history.length, SearchHistory.maxItems);
    expect(history.first, '词${SearchHistory.maxItems + 2}');
    expect(history, isNot(contains('词0')));
  });

  test('清空后历史为空', () async {
    await SearchHistory.add('A');
    await SearchHistory.clear();

    expect(await SearchHistory.load(), isEmpty);
  });

  test('本地数据损坏时返回空列表', () async {
    SharedPreferences.setMockInitialValues({'search_history': '不是JSON'});

    expect(await SearchHistory.load(), isEmpty);
  });

  test('关键词两端空白会被去掉', () async {
    await SearchHistory.add('  空格环绕  ');

    expect(await SearchHistory.load(), ['空格环绕']);
  });
}
