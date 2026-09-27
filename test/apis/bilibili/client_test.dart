import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://api.bilibili.com/x/web-interface/nav';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('bilibiliRequest', () {
    test('code=0 时返回 data', () async {
      final adapter = _mock();
      adapter.onGet(
        _url,
        (server) => server.reply(200, {
          'code': 0,
          'message': '0',
          'data': {'mid': 1},
        }),
      );

      final data = await bilibiliRequest('GET', _url);
      expect(data, {'mid': 1});
    });

    test('code 非 0 时抛 BilibiliError（含业务码与 message）', () async {
      final adapter = _mock();
      adapter.onGet(
        _url,
        (server) =>
            server.reply(200, {'code': -101, 'message': '账号未登录'}),
      );

      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(
          isA<BilibiliError>()
              .having((e) => e.code, 'code', -101)
              .having((e) => e.message, 'message', '账号未登录'),
        ),
      );
    });

    test('message 缺失时回退 msg 字段，均缺失时为未知错误', () async {
      final adapter = _mock();
      adapter.onGet(
        _url,
        (server) => server.reply(200, {'code': -400, 'msg': '请求错误'}),
      );
      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(isA<BilibiliError>().having((e) => e.message, 'message', '请求错误')),
      );

      final adapter2 = _mock();
      adapter2.onGet(_url, (server) => server.reply(200, {'code': -400}));
      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(isA<BilibiliError>().having((e) => e.message, 'message', '未知错误')),
      );
    });

    test('HTML 响应（风控页）抛 BilibiliError(-2) 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        _url,
        (server) => server.reply(
          200,
          '<html><body>风控验证</body></html>',
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(
          isA<BilibiliError>()
              .having((e) => e.code, 'code', -2)
              .having((e) => e.message, 'message', '响应格式异常'),
        ),
      );
    });

    test('响应缺少 code 或 code 非法时抛 BilibiliError(-2)', () async {
      final adapter = _mock();
      adapter.onGet(_url, (server) => server.reply(200, {'data': {}}));
      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );

      final adapter2 = _mock();
      adapter2.onGet(_url, (server) => server.reply(200, {'code': 'abc'}));
      await expectLater(
        bilibiliRequest('GET', _url),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });

    test('respHandler 返回 true 时直接使用其结果', () async {
      final adapter = _mock();
      adapter.onGet(_url, (server) => server.reply(200, 'raw'));

      final data = await bilibiliRequest(
        'GET',
        _url,
        respHandler: (response) => (true, '自定义结果'),
      );
      expect(data, '自定义结果');
    });

    test('respHandler 返回 false 时走标准处理且可取得响应头', () async {
      final adapter = _mock();
      adapter.onGet(
        _url,
        (server) => server.reply(
          200,
          {'code': 0, 'data': {'x': 1}},
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['SESSDATA=abc'],
          },
        ),
      );

      Headers? captured;
      final data = await bilibiliRequest(
        'GET',
        _url,
        respHandler: (response) {
          captured = response.headers;
          return (false, null);
        },
      );
      expect(captured?['set-cookie'], ['SESSDATA=abc']);
      expect(data, {'x': 1});
    });

    test('自动附加存储的 Cookie 请求头', () async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'SESSDATA=abc; bili_jct=xyz',
      });
      final adapter = _mock();
      String? cookieHeader;
      adapter.onGet(
        _url,
        (server) => server.replyCallback(200, (options) {
          cookieHeader = options.headers['Cookie'] as String?;
          return {'code': 0, 'data': null};
        }),
      );

      await bilibiliRequest('GET', _url);
      expect(cookieHeader, 'SESSDATA=abc; bili_jct=xyz');
    });

    test('无 Cookie 时不附加 Cookie 请求头', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = _mock();
      String? cookieHeader;
      adapter.onGet(
        _url,
        (server) => server.replyCallback(200, (options) {
          cookieHeader = options.headers['Cookie'] as String?;
          return {'code': 0, 'data': null};
        }),
      );

      await bilibiliRequest('GET', _url);
      expect(cookieHeader, isNull);
    });
  });
}
