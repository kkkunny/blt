import 'package:blt/consts/color.dart';
import 'package:blt/consts/search.dart';
import 'package:blt/widgets/search_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

void main() {
  setupPageTestEnv();

  group('SearchIdlePanel', () {
    testWidgets('展示历史与热搜，点击胶囊回调关键词', (tester) async {
      final tapped = <String>[];
      await pumpPage(
        tester,
        SearchIdlePanel(
          history: const ['历史词'],
          hotWords: const ['热搜词'],
          onSearch: tapped.add,
          onClearHistory: () {},
        ),
      );

      expect(find.text('搜索历史'), findsOneWidget);
      expect(find.text('热门搜索'), findsOneWidget);

      await tester.tap(find.text('历史词'));
      await tester.pump();
      await tester.tap(find.text('热搜词'));
      await tester.pump();

      expect(tapped, ['历史词', '热搜词']);
    });

    testWidgets('点击清空回调', (tester) async {
      var cleared = 0;
      await pumpPage(
        tester,
        SearchIdlePanel(
          history: const ['历史词'],
          hotWords: const [],
          onSearch: (_) {},
          onClearHistory: () => cleared++,
        ),
      );

      await tester.tap(find.text('清空'));
      await tester.pump();

      expect(cleared, 1);
    });

    testWidgets('没有历史时不展示历史区块与清空入口', (tester) async {
      await pumpPage(
        tester,
        SearchIdlePanel(
          history: const [],
          hotWords: const ['热搜词'],
          onSearch: (_) {},
          onClearHistory: () {},
        ),
      );

      expect(find.text('搜索历史'), findsNothing);
      expect(find.text('清空'), findsNothing);
      expect(find.text('热门搜索'), findsOneWidget);
    });

    testWidgets('历史和热搜都为空时展示引导文案', (tester) async {
      await pumpPage(
        tester,
        SearchIdlePanel(
          history: const [],
          hotWords: const [],
          onSearch: (_) {},
          onClearHistory: () {},
        ),
      );

      expect(find.text('输入关键词开始搜索'), findsOneWidget);
    });
  });

  group('SearchSuggestPanel', () {
    testWidgets('最多展示5条，点击回调关键词', (tester) async {
      final tapped = <String>[];
      await pumpPage(
        tester,
        SearchSuggestPanel(
          keyword: '洛',
          suggestions: const ['洛1', '洛2', '洛3', '洛4', '洛5', '洛6'],
          onSelected: tapped.add,
        ),
      );

      expect(find.text('洛6'), findsNothing);

      await tester.tap(find.text('洛2'));
      await tester.pump();

      expect(tapped, ['洛2']);
    });

    testWidgets('命中输入前缀的关键词用粉色高亮', (tester) async {
      await pumpPage(
        tester,
        SearchSuggestPanel(
          keyword: '洛天依',
          suggestions: const ['洛天依演唱会'],
          onSelected: (_) {},
        ),
      );

      final text = tester.widget<Text>(find.text('洛天依演唱会'));
      final span = text.textSpan! as TextSpan;
      final highlighted = span.children!
          .whereType<TextSpan>()
          .any((e) => e.style?.color == biliPink);
      expect(highlighted, isTrue);
    });
  });

  group('SearchResultHeader', () {
    testWidgets('展示关键词与结果总数', (tester) async {
      await pumpPage(
        tester,
        SearchResultHeader(
          keyword: '测试关键词',
          total: 123,
          order: SearchOrder.totalrank,
          duration: SearchDuration.all,
          onOrderChanged: (_) {},
          onDurationChanged: (_) {},
        ),
      );

      expect(find.text('「测试关键词」'), findsOneWidget);
      expect(find.text('共 123 条视频'), findsOneWidget);
    });

    testWidgets('点击排序与时长胶囊回调对应选项', (tester) async {
      SearchOrder? order;
      SearchDuration? duration;
      await pumpPage(
        tester,
        SearchResultHeader(
          keyword: '关键词',
          total: 1,
          order: SearchOrder.totalrank,
          duration: SearchDuration.all,
          onOrderChanged: (v) => order = v,
          onDurationChanged: (v) => duration = v,
        ),
      );

      await tester.tap(find.text('最多播放'));
      await tester.pump();
      expect(order, SearchOrder.click);

      await tester.tap(find.text('10-30分钟'));
      await tester.pump();
      expect(duration, SearchDuration.medium);
    });

    testWidgets('搜索中展示进行中文案，无结果时不展示总数', (tester) async {
      await pumpPage(
        tester,
        SearchResultHeader(
          keyword: '关键词',
          total: 0,
          searching: true,
          order: SearchOrder.totalrank,
          duration: SearchDuration.all,
          onOrderChanged: (_) {},
          onDurationChanged: (_) {},
        ),
      );

      expect(find.text('正在搜索…'), findsOneWidget);
      expect(find.text('共 0 条视频'), findsNothing);

      await pumpPage(
        tester,
        SearchResultHeader(
          keyword: '关键词',
          total: 0,
          order: SearchOrder.totalrank,
          duration: SearchDuration.all,
          onOrderChanged: (_) {},
          onDurationChanged: (_) {},
        ),
      );

      expect(find.text('正在搜索…'), findsNothing);
      expect(find.textContaining('共'), findsNothing);
    });
  });
}
