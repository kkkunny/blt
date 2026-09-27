import 'package:blt/pages/splash.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/page_test_env.dart';

const _navUrl = 'https://api.bilibili.com/x/web-interface/nav';

Widget _host() => UiScale(
  factor: 1,
  child: GetMaterialApp(
    initialRoute: '/',
    getPages: [
      GetPage(name: '/', page: () => const SplashPage()),
      GetPage(name: '/home', page: () => const Text('home-placeholder')),
    ],
  ),
);

// 等待 splash 的登录校验与 500ms 延迟后完成跳转
Future<void> _waitSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

void main() {
  setupPageTestEnv();

  testWidgets('未登录（无 cookie）直接进入主页', (tester) async {
    await tester.pumpWidget(_host());
    await _waitSplash(tester);

    expect(find.text('home-placeholder'), findsOneWidget);
    expect(loginInfoNotifier.value.isLogin, false);
  });

  testWidgets('登录态校验成功写入登录信息', (tester) async {
    SharedPreferences.setMockInitialValues({
      'bilibili_cookie': 'SESSDATA=abc',
    });
    mockHttp().onGet(
      _navUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'mid': 123,
          'uname': '测试用户',
          'face': 'avatar.jpg',
          'level_info': {'current_level': 6},
        },
      }),
    );

    await tester.pumpWidget(_host());
    await _waitSplash(tester);

    expect(loginInfoNotifier.value.isLogin, true);
    expect(loginInfoNotifier.value.mid, 123);
    expect(find.text('home-placeholder'), findsOneWidget);
  });

  testWidgets('cookie 失效（-101）时清除本地登录信息', (tester) async {
    SharedPreferences.setMockInitialValues({
      'bilibili_cookie': 'SESSDATA=abc',
    });
    mockHttp().onGet(
      _navUrl,
      (server) => server.reply(200, {'code': -101, 'message': '账号未登录'}),
    );

    await tester.pumpWidget(_host());
    await _waitSplash(tester);

    expect(loginInfoNotifier.value.isLogin, false);
    expect(await loadCookie(), isEmpty);
    expect(find.text('home-placeholder'), findsOneWidget);
  });

  testWidgets('登录校验网络异常时不崩溃并继续进入主页', (tester) async {
    SharedPreferences.setMockInitialValues({
      'bilibili_cookie': 'SESSDATA=abc',
    });
    mockHttp().onGet(
      _navUrl,
      (server) => server.reply(200, '<html>风控</html>', headers: {
        'content-type': ['text/html'],
      }),
    );

    await tester.pumpWidget(_host());
    await _waitSplash(tester);

    expect(loginInfoNotifier.value.isLogin, false);
    expect(find.text('home-placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
