import 'package:blt/pages/search.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/storages/search_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/page_test_env.dart';

const _searchUrl = 'https://api.bilibili.com/x/web-interface/wbi/search/type';
const _hotUrl = 'https://api.bilibili.com/x/web-interface/wbi/search/square';

const _sizes = [
  Size(1280, 720),
  Size(1920, 1080),
  Size(3840, 2160),
  Size(1600, 1200),
  Size(2560, 1080),
];

Map<String, dynamic> _item(int i) => {
  'type': 'video',
  'aid': 170000 + i,
  'bvid': 'BV$i',
  'title': '搜索结果视频标题$i',
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

void _mockHotWords(DioAdapter adapter) {
  adapter.onGet(
    _hotUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'trending': {
          'list': [
            for (var i = 0; i < 10; i++) {'keyword': '热门搜索关键词$i'},
          ],
        },
      },
    }),
  );
}

void _mockSearch(DioAdapter adapter, {required int count}) {
  adapter.onGet(
    _searchUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'numResults': count,
        'numPages': 3,
        'result': [for (var i = 0; i < count; i++) _item(i)],
      },
    }),
  );
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  await pumpPage(tester, const SearchPage(), size: size);
  await flush(tester);
}

Future<void> _search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await flush(tester);
}

void main() {
  setupPageTestEnv();

  testWidgets('未搜索态（历史+热搜）多分辨率无溢出', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockHotWords(adapter);
    for (var i = 0; i < SearchHistory.maxItems; i++) {
      await SearchHistory.add('很长的历史搜索关键词$i');
    }

    for (final size in _sizes) {
      await _pump(tester, size: size);
      expect(find.text('搜索历史'), findsOneWidget, reason: '$size');
      expect(find.text('热门搜索'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size 下未搜索态不应溢出');
    }
  });

  testWidgets('结果态多分辨率无溢出', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockHotWords(adapter);
    _mockSearch(adapter, count: 20);

    for (final size in _sizes) {
      await _pump(tester, size: size);
      await _search(tester, '一个比较长的测试关键词');
      expect(find.text('搜索结果视频标题0'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size 下结果态不应溢出');
    }
  });

  testWidgets('空结果与错误态多分辨率无溢出', (tester) async {
    _login();
    final adapter = mockHttp();
    _mockHotWords(adapter);
    _mockSearch(adapter, count: 0);

    for (final size in _sizes) {
      await _pump(tester, size: size);
      await _search(tester, '没有结果的词');
      expect(
        find.text('没有找到「没有结果的词」相关视频'),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size 下空态不应溢出');
    }

    final errorAdapter = mockHttp();
    _mockHotWords(errorAdapter);
    errorAdapter.onGet(
      _searchUrl,
      (server) => server.reply(200, {'code': -400, 'message': '请求错误'}),
    );

    for (final size in _sizes) {
      await _pump(tester, size: size);
      await _search(tester, '出错的词');
      expect(find.text('加载失败，请稍后重试'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size 下错误态不应溢出');
    }
  });

  testWidgets('未登录引导在多分辨率无溢出', (tester) async {
    final adapter = mockHttp();
    _mockSearch(adapter, count: 1);

    for (final size in _sizes) {
      await _pump(tester, size: size);
      expect(find.text('登录后即可搜索视频'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size 下登录引导不应溢出');
    }
  });
}
