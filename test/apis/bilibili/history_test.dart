import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

Map<String, dynamic> _historyItem() => {
  'title': '历史视频',
  'cover': 'https://i0.hdslb.com/cover.jpg',
  'duration': 3723,
  'goto': 'av',
  'history': {'oid': 170001, 'bvid': 'BV1', 'cid': 279786},
  'author_mid': 123,
  'author_name': '测试UP主',
  'author_face': 'avatar.jpg',
  'view_at': 1700000000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MediaPlayInfo.fromJson', () {
    test('字段类型错时降级默认值', () {
      final info = MediaPlayInfo.fromJson({
        'last_play_cid': '279786',
        'last_play_time': 'bad',
        'online_count': null,
      });
      expect(info.lastPlayCid, 279786);
      expect(info.lastPlayTime, Duration.zero);
      expect(info.onlineCount, 0);
    });
  });

  group('HistoryCursor.fromJson', () {
    test('字段缺失/类型错时降级默认值', () {
      final cursor = HistoryCursor.fromJson({
        'max': 'bad',
        'view_at': null,
        'business': 123,
      });
      expect(cursor.max, 0);
      expect(cursor.viewAt.millisecondsSinceEpoch, 0);
      expect(cursor.business, '');
    });

    test('正常解析', () {
      final cursor = HistoryCursor.fromJson({
        'max': 123,
        'view_at': 1700000000,
        'business': 'archive',
      });
      expect(cursor.max, 123);
      expect(cursor.business, 'archive');
    });
  });

  group('listHistory', () {
    const url = 'https://api.bilibili.com/x/web-interface/history/cursor';

    test('正常解析游标与列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'cursor': {'max': 123, 'view_at': 1700000000, 'business': 'archive'},
            'list': [_historyItem()],
          },
        }),
      );

      final (cursor, videos) = await listHistory();
      expect(cursor.max, 123);
      expect(videos.single.avid, 170001);
    });

    test('坏项丢弃、好项保留', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'cursor': {'max': 123, 'view_at': 1700000000, 'business': 'archive'},
            'list': [
              _historyItem(),
              {
                'title': '缺 history 的坏项',
                'goto': 'av',
              },
              'not-a-map',
            ],
          },
        }),
      );

      final (_, videos) = await listHistory();
      expect(videos.length, 1);
      expect(videos.single.title, '历史视频');
    });

    test('data 为空时不抛异常', () async {
      final adapter = _mock();
      adapter.onGet(url, (server) => server.reply(200, {'code': 0, 'data': null}));

      final (cursor, videos) = await listHistory();
      expect(cursor.max, 0);
      expect(videos, isEmpty);
    });
  });
}
