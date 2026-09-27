import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/dynamic.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

Map<String, dynamic> _dynamicItem() => {
  'modules': {
    'module_author': {
      'mid': 123,
      'name': 'UP',
      'face': 'f',
      'pub_ts': '1700000000',
    },
    'module_dynamic': {
      'major': {
        'archive': {
          'aid': '170001',
          'bvid': 'BV1',
          'title': '动态视频',
          'cover': 'c',
          'duration_text': '10:30',
        },
      },
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('avidToDynamicId', () {
    const url =
        'https://api.bilibili.com/x/polymer/web-dynamic/v1/detail';

    test('正常解析动态 id', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'item': {'id_str': '901234567890123456'},
          },
        }),
      );

      expect(await avidToDynamicId(170001), '901234567890123456');
    });

    test('动态 id 缺失时抛 BilibiliError 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      await expectLater(
        avidToDynamicId(170001),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });

  group('GetDynamicPortalResponse.fromJson', () {
    test('up_list 缺失时返回空列表', () {
      final resp = GetDynamicPortalResponse.fromJson({});
      expect(resp.ups, isEmpty);
    });

    test('坏项丢弃、好项保留', () {
      final resp = GetDynamicPortalResponse.fromJson({
        'up_list': {
          'items': [
            {'mid': 123, 'uname': 'UP', 'face': 'f'},
            {'uname': '缺 mid'},
            'not-a-map',
          ],
        },
      });
      expect(resp.ups.length, 1);
      expect(resp.ups.single.mid, 123);
    });
  });

  group('ListDynamicResponse.fromJson', () {
    test('offset 为数字字符串/空串时容错', () {
      final resp = ListDynamicResponse.fromJson({
        'has_more': 1,
        'items': [_dynamicItem()],
        'offset': '123',
      });
      expect(resp.hasMore, true);
      expect(resp.offset, 123);
      expect(resp.medias.single.avid, 170001);

      final lastPage = ListDynamicResponse.fromJson({
        'has_more': false,
        'items': [],
        'offset': '',
      });
      expect(lastPage.offset, 0);
    });

    test('坏项丢弃、好项保留', () {
      final resp = ListDynamicResponse.fromJson({
        'has_more': true,
        'items': [_dynamicItem(), {'modules': {}}, 'bad'],
        'offset': 1,
      });
      expect(resp.medias.length, 1);
    });
  });

  group('listDynamic', () {
    const url = 'https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all';

    test('data 为空时不抛异常', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': null}),
      );

      final resp = await listDynamic();
      expect(resp.medias, isEmpty);
      expect(resp.hasMore, false);
    });
  });
}
