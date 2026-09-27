import 'package:blt/pages/search.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/storages/search_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/page_test_env.dart';

const _searchUrl = 'https://api.bilibili.com/x/web-interface/wbi/search/type';
const _hotUrl = 'https://api.bilibili.com/x/web-interface/wbi/search/square';
const _suggestUrl = 'https://s.search.bilibili.com/main/suggest';

Map<String, dynamic> _searchItem({
  int aid = 170001,
  String title = '搜索结果视频',
}) => {
  'type': 'video',
  'aid': aid,
  'bvid': 'BV$aid',
  'title': title,
  'pic': '//i0.hdslb.com/cover.jpg',
  'duration': '10:30',
  'mid': 123,
  'author': '测试UP主',
  'upic': '//i0.hdslb.com/face.jpg',
  'pubdate': 1700000000,
};

void _login() {
  loginInfoNotifier.value = LoginInfo.login(
    mid: 1,
    nickname: '测试用户',
    avatar: 'https://example.invalid/avatar.jpg',
  );
}

// 记录每次搜索请求的查询参数
List<Map<String, dynamic>> _mockSearch(
  DioAdapter adapter, {
  Map<String, dynamic> Function(Map<String, dynamic> query)? respond,
}) {
  final requests = <Map<String, dynamic>>[];
  adapter.onGet(
    _searchUrl,
    (server) => server.replyCallback(200, (options) {
      final query = Map<String, dynamic>.from(options.queryParameters);
      requests.add(query);
      final data =
          respond?.call(query) ??
          {
            'numResults': 1,
            'numPages': 1,
            'result': [_searchItem()],
          };
      return {'code': 0, 'data': data};
    }),
  );
  return requests;
}

void _mockError(DioAdapter adapter, String url) {
  adapter.onGet(
    url,
    (server) => server.reply(200, {'code': -400, 'message': '请求错误'}),
  );
}

void _mockHotWords(DioAdapter adapter, List<String> words) {
  adapter.onGet(
    _hotUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'trending': {
          'list': [for (final word in words) {'keyword': word}],
        },
      },
    }),
  );
}

void _mockSuggest(DioAdapter adapter, List<String> words) {
  adapter.onGet(
    _suggestUrl,
    (server) => server.reply(200, {
      'code': 0,
      'result': {
        'tag': [for (final word in words) {'value': word}],
      },
    }),
  );
}

Future<void> _search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await flush(tester);
}

void main() {
  setupPageTestEnv();

  testWidgets('搜索成功展示结果与总数', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockSearch(adapter);
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.text('搜索结果视频'), findsOneWidget);
    expect(find.text('「测试关键词」'), findsOneWidget);
    expect(find.text('共 1 条视频'), findsOneWidget);
  });

  testWidgets('空结果展示空态文案', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockSearch(
      adapter,
      respond: (_) => {'numResults': 0, 'numPages': 0, 'result': []},
    );
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.text('没有找到「测试关键词」相关视频'), findsOneWidget);
  });

  testWidgets('搜索失败展示错误态而不是未捕获异常', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockError(adapter, _searchUrl);
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.text('加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未登录展示登录引导且不发起搜索请求', (tester) async {
    final adapter = mockHttp();
    final requests = _mockSearch(adapter);

    await pumpPage(tester, const SearchPage());
    await flush(tester);

    expect(find.text('登录后即可搜索视频'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);

    await _search(tester, '测试关键词');
    expect(requests, isEmpty);
  });

  testWidgets('进入页面展示热搜，点击热搜直接搜索', (tester) async {
    _login();
    final adapter = mockHttp();
    final requests = _mockSearch(adapter);
    _mockHotWords(adapter, ['热搜甲', '热搜乙']);

    await pumpPage(tester, const SearchPage());
    await flush(tester);

    expect(find.text('热门搜索'), findsOneWidget);
    expect(find.text('热搜甲'), findsOneWidget);

    await tester.tap(find.text('热搜甲'));
    await flush(tester);

    expect(requests.single['keyword'], '热搜甲');
    expect(find.text('搜索结果视频'), findsOneWidget);
  });

  testWidgets('搜索成功后写入历史，点击历史可直接搜索', (tester) async {
    _login();
    final adapter = mockHttp();
    final requests = _mockSearch(adapter);
    _mockHotWords(adapter, ['热搜甲']);

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '历史关键词');

    expect(await SearchHistory.load(), ['历史关键词']);

    // 重新进入页面：历史词可一键搜索
    await pumpPage(tester, SearchPage(key: UniqueKey()));
    await flush(tester);

    expect(find.text('搜索历史'), findsOneWidget);
    await tester.tap(find.text('历史关键词'));
    await flush(tester);

    expect(requests.last['keyword'], '历史关键词');
    expect(find.text('搜索结果视频'), findsOneWidget);
  });

  testWidgets('清空历史弹确认框，确认后历史为空', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockSearch(adapter);
    _mockHotWords(adapter, ['热搜甲']);
    await SearchHistory.add('历史关键词');

    await pumpPage(tester, const SearchPage());
    await flush(tester);

    await tester.tap(find.text('清空'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('清空搜索历史'), findsOneWidget);

    await tester.tap(find.text('清空').last);
    await flush(tester);

    expect(await SearchHistory.load(), isEmpty);
    expect(find.text('搜索历史'), findsNothing);
  });

  testWidgets('输入触发联想，点击联想词直接搜索', (tester) async {
    _login();
    final adapter = mockHttp();
    final requests = _mockSearch(adapter);
    _mockSuggest(adapter, ['洛天依', '洛天依演唱会']);
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);

    await tester.enterText(find.byType(TextField), '洛');
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);

    expect(find.text('洛天依演唱会'), findsOneWidget);

    await tester.tap(find.text('洛天依'));
    await flush(tester);

    expect(requests.single['keyword'], '洛天依');
    expect(find.text('搜索结果视频'), findsOneWidget);
  });

  testWidgets('切换排序与时长会用新参数重搜第一页', (tester) async {
    _login();
    final adapter = mockHttp();
    final requests = _mockSearch(
      adapter,
      respond: (_) => {
        'numResults': 20,
        'numPages': 2,
        'result': [_searchItem()],
      },
    );
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');
    expect(requests.last['order'], 'totalrank');
    expect(requests.last['duration'], 0);

    await tester.tap(find.text('最多播放'));
    await flush(tester);
    expect(requests.last['keyword'], '测试关键词');
    expect(requests.last['order'], 'click');
    expect(requests.last['page'], 1);

    await tester.tap(find.text('10-30分钟'));
    await flush(tester);
    expect(requests.last['duration'], 2);
    expect(requests.last['page'], 1);
  });

  testWidgets('联想面板展开时按返回键只收面板', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockSearch(adapter);
    _mockSuggest(adapter, ['洛天依']);
    _mockHotWords(adapter, const []);

    await pumpPage(tester, const SearchPage());
    await flush(tester);

    await tester.enterText(find.byType(TextField), '洛');
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);
    expect(find.text('洛天依'), findsOneWidget);

    // goBack 在测试环境没有默认物理键映射，显式指定一个
    await simulateKeyDownEvent(
      LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
    );
    await simulateKeyUpEvent(
      LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
    );
    await tester.pump();

    expect(find.text('洛天依'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('再次点击侧栏搜索入口会聚焦输入框', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockSearch(adapter);
    _mockHotWords(adapter, const ['热搜甲']);
    final tapped = ValueNotifier(0);

    await pumpPage(tester, SearchPage(tappedListener: tapped));
    await flush(tester);

    // 进入页面时焦点不在输入框上（避免直接弹出软键盘）
    final inputBefore = tester.widget<TextField>(find.byType(TextField));
    expect(inputBefore.focusNode?.hasFocus, isFalse);

    tapped.value = DateTime.now().microsecondsSinceEpoch;
    await tester.pump();

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.focusNode?.hasFocus, isTrue);

    tapped.dispose();
  });

  testWidgets('加载更多失败后重试重跑同一页且不清空已有结果', (tester) async {
    _login();
    final adapter = mockHttp();
    var pageTwoCalls = 0;
    final pageRequests = <int>[];
    adapter.onGet(
      _searchUrl,
      (server) => server.replyCallback(200, (options) {
        final page = options.queryParameters['page'] as int? ?? 1;
        pageRequests.add(page);
        if (page > 1) {
          pageTwoCalls++;
          if (pageTwoCalls == 1) {
            return {'code': -400, 'message': '请求错误'};
          }
        }
        return {
          'code': 0,
          'data': {
            'numResults': 100,
            'numPages': 5,
            'result': [
              if (page == 1)
                for (var i = 0; i < 20; i++)
                  _searchItem(aid: 1000 + i, title: '搜索视频$i')
              else
                _searchItem(aid: 2000, title: '第二页视频'),
            ],
          },
        };
      }),
    );

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');
    expect(find.text('搜索视频0'), findsOneWidget);

    // 滚动到底部触发加载更多（第一次失败）
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -8000));
    await flush(tester);

    // 已加载的第一页数据仍在，底部展示错误态
    expect(find.text('搜索视频19'), findsOneWidget);
    expect(find.text('加载失败，请稍后重试'), findsOneWidget);

    // 重试同一页，成功后错误态消失
    await tester.tap(find.text('重试'));
    await flush(tester);

    expect(pageRequests, [1, 2, 2]);
    expect(find.text('加载失败，请稍后重试'), findsNothing);
  });
}
