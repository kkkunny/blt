import 'package:blt/pages/search.dart';
import 'package:blt/storages/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

const _searchUrl =
    'https://api.bilibili.com/x/web-interface/wbi/search/type';

Map<String, dynamic> _searchItem() => {
  'type': 'video',
  'aid': 170001,
  'bvid': 'BV1',
  'title': '搜索结果视频',
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

Future<void> _search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await flush(tester);
}

void main() {
  setupPageTestEnv();

  testWidgets('搜索成功展示结果', (tester) async {
    _login();
    final adapter = mockHttp();
    adapter.onGet(
      _searchUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'result': [_searchItem()],
        },
      }),
    );

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.text('搜索结果视频'), findsOneWidget);
  });

  testWidgets('空结果展示空态组件', (tester) async {
    _login();
    final adapter = mockHttp();
    adapter.onGet(
      _searchUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {'result': []},
      }),
    );

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('搜索失败展示错误提示而不是未捕获异常', (tester) async {
    _login();
    final adapter = mockHttp();
    adapter.onGet(
      _searchUrl,
      (server) => server.reply(200, {'code': -400, 'message': '请求错误'}),
    );

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(find.text('错误：请求错误'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未登录时不发起搜索请求', (tester) async {
    var requested = false;
    final adapter = mockHttp();
    adapter.onGet(
      _searchUrl,
      (server) => server.replyCallback(200, (options) {
        requested = true;
        return {'code': 0, 'data': {'result': []}};
      }),
    );

    await pumpPage(tester, const SearchPage());
    await flush(tester);
    await _search(tester, '测试关键词');

    expect(requested, false);
  });
}
