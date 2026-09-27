import 'package:blt/pages/recommend.dart';
import 'package:blt/widgets/video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

const _rcmdUrl =
    'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd';

void main() {
  setupPageTestEnv();

  testWidgets('加载中展示刷新组件，成功后展示卡片', (tester) async {
    final adapter = mockHttp();
    adapter.onGet(
      _rcmdUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'item': [feedVideoJson(title: '推荐视频A')],
        },
      }),
    );
    final tapped = ValueNotifier(0);
    addTearDown(tapped.dispose);

    await pumpPage(tester, RecommendPage(tapped));
    expect(find.text('加载中...'), findsOneWidget);

    await flush(tester);
    expect(find.text('推荐视频A'), findsOneWidget);
    expect(find.text('加载中...'), findsNothing);
  });

  testWidgets('失败展示错误与重试，重试成功后展示数据', (tester) async {
    var fail = true;
    final adapter = mockHttp();
    adapter.onGet(
      _rcmdUrl,
      (server) => server.replyCallback(200, (options) {
        if (fail) return {'code': -400, 'message': '请求错误'};
        return {
          'code': 0,
          'data': {
            'item': [feedVideoJson(title: '重试成功')],
          },
        };
      }),
    );
    final tapped = ValueNotifier(0);
    addTearDown(tapped.dispose);

    await pumpPage(tester, RecommendPage(tapped));
    await flush(tester);
    expect(find.text('加载失败，请稍后重试'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('重试'));
    await flush(tester);
    expect(find.text('重试成功'), findsOneWidget);
  });

  testWidgets('空数据显示空态组件', (tester) async {
    final adapter = mockHttp();
    adapter.onGet(
      _rcmdUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {'item': []},
      }),
    );
    final tapped = ValueNotifier(0);
    addTearDown(tapped.dispose);

    await pumpPage(tester, RecommendPage(tapped));
    await flush(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(VideoCard), findsNothing);
  });

  testWidgets('聚焦到最后一个卡片时加载下一页', (tester) async {
    var loadCount = 0;
    final adapter = mockHttp();
    adapter.onGet(
      _rcmdUrl,
      (server) => server.replyCallback(200, (options) {
        loadCount++;
        return {
          'code': 0,
          'data': {
            'item': [feedVideoJson(aid: loadCount, title: '第$loadCount页视频')],
          },
        };
      }),
    );
    final tapped = ValueNotifier(0);
    addTearDown(tapped.dispose);

    await pumpPage(tester, RecommendPage(tapped));
    await flush(tester);
    expect(find.text('第1页视频'), findsOneWidget);

    // 模拟聚焦到最后一个卡片（触发 preload 下一页）
    tester.widget<VideoCard>(find.byType(VideoCard).first).onFocus?.call();
    await flush(tester);

    expect(loadCount, 2);
    expect(find.text('第2页视频'), findsOneWidget);
  });
}
