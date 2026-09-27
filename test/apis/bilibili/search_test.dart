import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

Map<String, dynamic> _searchItem() => {
  'type': 'video',
  'aid': 170001,
  'bvid': 'BV1',
  'title': '搜索结果',
  'pic': '//i0.hdslb.com/cover.jpg',
  'duration': '10:30',
  'mid': 123,
  'author': 'UP',
  'upic': '//i0.hdslb.com/face.jpg',
  'pubdate': 1700000000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('searchVideos', () {
    const url = 'https://api.bilibili.com/x/web-interface/wbi/search/type';

    test('正常解析结果并补全封面协议', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'result': [_searchItem()],
          },
        }),
      );

      final videos = await searchVideos('测试');
      expect(videos.single.avid, 170001);
      expect(videos.single.cover, 'https://i0.hdslb.com/cover.jpg');
    });

    test('坏项丢弃、好项保留', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'result': [
              _searchItem(),
              {'title': '缺 aid 的坏项'},
              'bad',
            ],
          },
        }),
      );

      final videos = await searchVideos('测试');
      expect(videos.length, 1);
    });

    test('result 缺失时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      expect(await searchVideos('测试'), isEmpty);
    });
  });
}
