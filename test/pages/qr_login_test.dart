import 'package:blt/pages/qr_login.dart';
import 'package:blt/storages/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/page_test_env.dart';

const _generateUrl =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
const _pollUrl =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';
const _spiUrl = 'https://api.bilibili.com/x/frontend/finger/spi';
const _navUrl = 'https://api.bilibili.com/x/web-interface/nav';

// 打开登录弹窗
Future<void> _openDialog(WidgetTester tester) async {
  await pumpPage(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showQrLoginDialog(context),
        child: const Text('打开登录'),
      ),
    ),
  );
  await tester.tap(find.text('打开登录'));
  await tester.pump();
}

void main() {
  setupPageTestEnv();

  testWidgets('创建二维码失败展示错误与重试，重试成功后展示二维码', (tester) async {
    var fail = true;
    final adapter = mockHttp();
    adapter.onGet(
      _generateUrl,
      (server) => server.replyCallback(200, (options) {
        if (fail) return {'code': -400, 'message': '请求错误'};
        return {
          'code': 0,
          'data': {
            'qrcode_key': 'key-1',
            'url': 'https://example.invalid/qr',
          },
        };
      }),
    );

    await _openDialog(tester);
    await flush(tester);
    expect(find.text('发生错误，请点击二维码重试'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('重试'));
    await flush(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('等待扫码'), findsOneWidget);
  });

  testWidgets('轮询各状态：等待扫码 → 已扫码 → 过期', (tester) async {
    var pollCode = 86101;
    final adapter = mockHttp();
    adapter.onGet(
      _generateUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'qrcode_key': 'key-1',
          'url': 'https://example.invalid/qr',
        },
      }),
    );
    adapter.onGet(
      _pollUrl,
      (server) => server.replyCallback(200, (options) {
        return {
          'code': 0,
          'data': {'code': pollCode},
        };
      }),
    );

    await _openDialog(tester);
    await flush(tester);
    expect(find.text('等待扫码'), findsOneWidget);

    // 第一次轮询：等待扫码
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(find.text('等待扫码'), findsOneWidget);

    // 第二次轮询：已扫码
    pollCode = 86090;
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(find.text('已扫码，请在手机端确认'), findsOneWidget);

    // 第三次轮询：已过期
    pollCode = 86038;
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(find.text('二维码已过期，请点击二维码刷新'), findsOneWidget);
  });

  testWidgets('确认登录后写入登录态并关闭弹窗', (tester) async {
    final adapter = mockHttp();
    adapter.onGet(
      _generateUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'qrcode_key': 'key-1',
          'url': 'https://example.invalid/qr',
        },
      }),
    );
    adapter.onGet(
      _pollUrl,
      (server) => server.reply(
        200,
        {
          'code': 0,
          'data': {'code': 0, 'refresh_token': 'rt-1'},
        },
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'set-cookie': ['SESSDATA=abc'],
        },
      ),
    );
    adapter.onGet(
      _spiUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {'b_3': 'buvid3-value', 'b_4': 'buvid4-value'},
      }),
    );
    adapter.onGet(
      _navUrl,
      (server) => server.reply(200, {
        'code': 0,
        'data': {
          'mid': 123,
          'uname': '登录用户',
          'face': 'avatar.jpg',
          'level_info': {'current_level': 6},
        },
      }),
    );

    await _openDialog(tester);
    await flush(tester);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await flush(tester);

    expect(loginInfoNotifier.value.isLogin, true);
    expect(loginInfoNotifier.value.mid, 123);
    expect(find.text('打开登录'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
}
