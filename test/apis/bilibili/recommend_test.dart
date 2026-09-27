import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/recommend.dart';
import 'package:blt/models/video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

Map<String, dynamic> _feedItem({String goto = 'av'}) => {
  'goto': goto,
  'aid': 170001,
  'bvid': 'BV1',
  'cid': 279786,
  'title': '推荐视频',
  'pic': 'https://i0.hdslb.com/cover.jpg',
  'duration': 3723,
  'owner': {'mid': 123, 'name': 'UP', 'face': 'f'},
  'pubdate': 1700000000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('listRecommendVideos', () {
    const url =
        'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd';

    test('过滤非视频媒体与坏数据', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'item': [
              _feedItem(),
              _feedItem(goto: 'live'),
              {'goto': 'av', 'title': '缺 aid'},
              'bad',
            ],
          },
        }),
      );

      final videos = await listRecommendVideos();
      expect(videos.length, 1);
      expect(videos.single.type, MediaType.video);
    });

    test('data/item 缺失时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': null}),
      );

      expect(await listRecommendVideos(), isEmpty);
    });
  });

  group('fetchRelatedVideos', () {
    const url = 'https://api.bilibili.com/x/web-interface/archive/related';

    test('坏项丢弃、好项保留', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': [_feedItem(), {'title': '坏项'}],
        }),
      );

      final videos = await fetchRelatedVideos(avid: 170001);
      expect(videos.length, 1);
    });

    test('data 非列表时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': null}),
      );

      expect(await fetchRelatedVideos(avid: 170001), isEmpty);
    });
  });
}
