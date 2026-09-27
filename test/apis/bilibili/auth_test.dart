import 'package:blt/apis/bilibili/auth.dart';
import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QR.fromJson', () {
    test('正常解析', () {
      final qr = QR.fromJson({
        'qrcode_key': 'key-1',
        'url': 'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=key-1',
      });
      expect(qr.key, 'key-1');
    });

    test('qrcode_key/url 缺失时抛 BilibiliError', () {
      expect(
        () => QR.fromJson({'qrcode_key': 'key-1'}),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
      expect(
        () => QR.fromJson({'url': 'https://x'}),
        throwsA(isA<BilibiliError>()),
      );
    });
  });

  group('QRStatus.fromJson', () {
    test('四种已知状态', () {
      expect(QRStatus.fromJson({'code': 0}).state, QRState.confirmed);
      expect(QRStatus.fromJson({'code': 86038}).state, QRState.expired);
      expect(QRStatus.fromJson({'code': 86090}).state, QRState.scanned);
      expect(QRStatus.fromJson({'code': 86101}).state, QRState.waiting);
    });

    test('code 为字符串数字也可识别', () {
      expect(QRStatus.fromJson({'code': '86101'}).state, QRState.waiting);
    });

    test('未知 code 抛 BilibiliError 而不是裸 Exception', () {
      expect(
        () => QRStatus.fromJson({'code': 99999, 'message': '内部错误'}),
        throwsA(
          isA<BilibiliError>()
              .having((e) => e.code, 'code', 99999)
              .having((e) => e.message, 'message', '内部错误'),
        ),
      );
    });
  });

  group('CookieStatus/IsNeedRefreshCookieResponse', () {
    test('字段类型错时降级默认值', () {
      final status = CookieStatus.fromJson({'refresh': 1, 'timestamp': 'bad'});
      expect(status.refresh, true);
      expect(status.timestamp, 0);

      final resp = IsNeedRefreshCookieResponse.fromJson({
        'refresh': 'x',
        'timestamp': 1700000000,
      });
      expect(resp.needRefresh, false);
      expect(resp.timestamp, 1700000000);
    });
  });

  group('checkQRStatus', () {
    const pollUrl =
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';
    const spiUrl = 'https://api.bilibili.com/x/frontend/finger/spi';

    test('确认登录时解析 set-cookie 并补全 buvid', () async {
      final adapter = _mock();
      adapter.onGet(
        pollUrl,
        (server) => server.reply(
          200,
          {
            'code': 0,
            'data': {'code': 0, 'refresh_token': 'rt-1'},
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['SESSDATA=abc; Path=/; HttpOnly', 'bad'],
          },
        ),
      );
      adapter.onGet(
        spiUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'b_3': 'buvid3-value', 'b_4': 'buvid4-value'},
        }),
      );

      final status = await checkQRStatus('key-1');
      expect(status.state, QRState.confirmed);
      expect(status.refreshToken, 'rt-1');
      final names = status.cookies.map((c) => c.name).toList();
      expect(names, containsAll(['SESSDATA', 'buvid3', 'buvid4']));
    });

    test('set-cookie 缺失时不崩溃，仅补全 buvid', () async {
      final adapter = _mock();
      adapter.onGet(
        pollUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'code': 0, 'refresh_token': 'rt-1'},
        }),
      );
      adapter.onGet(
        spiUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'b_3': 'b3', 'b_4': 'b4'},
        }),
      );

      final status = await checkQRStatus('key-1');
      expect(status.state, QRState.confirmed);
      expect(status.cookies.map((c) => c.name), ['buvid3', 'buvid4']);
    });

    test('等待扫码状态不请求 buvid', () async {
      final adapter = _mock();
      adapter.onGet(
        pollUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'code': 86101},
        }),
      );

      final status = await checkQRStatus('key-1');
      expect(status.state, QRState.waiting);
    });
  });

  group('getRefreshCsrf', () {
    const url = 'https://www.bilibili.com/correspond/1/abc';

    test('从 HTML 提取 refresh_csrf', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(
          200,
          '<html><body><div id="1-name">csrf-123</div></body></html>',
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      expect(await getRefreshCsrf('abc'), 'csrf-123');
    });

    test('HTML 结构不符时抛 BilibiliError 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(
          200,
          '<html><body>风控</body></html>',
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      await expectLater(
        getRefreshCsrf('abc'),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });

  group('refreshCookie', () {
    const url =
        'https://passport.bilibili.com/x/passport-login/web/cookie/refresh';

    test('正常刷新返回 cookie 与新 refresh_token', () async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = _mock();
      adapter.onPost(
        url,
        data: Matchers.any,
        (server) => server.reply(
          200,
          {
            'code': 0,
            'data': {'refresh_token': 'rt-2'},
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['SESSDATA=new; Path=/'],
          },
        ),
      );

      final (cookies, refreshToken) = await refreshCookie('csrf', 'rt-1');
      expect(cookies.single.name, 'SESSDATA');
      expect(cookies.single.value, 'new');
      expect(refreshToken, 'rt-2');
    });

    test('set-cookie 缺失时抛 BilibiliError 而不是 null check 崩溃', () async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = _mock();
      adapter.onPost(
        url,
        data: Matchers.any,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'refresh_token': 'rt-2'},
        }),
      );

      await expectLater(
        refreshCookie('csrf', 'rt-1'),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });

    test('refresh_token 缺失时抛 BilibiliError', () async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = _mock();
      adapter.onPost(
        url,
        data: Matchers.any,
        (server) => server.reply(
          200,
          {
            'code': 0,
            'data': {},
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['SESSDATA=new'],
          },
        ),
      );

      await expectLater(
        refreshCookie('csrf', 'rt-1'),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });
}
