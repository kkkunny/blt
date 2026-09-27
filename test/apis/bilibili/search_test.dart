import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/search.dart';
import 'package:blt/consts/search.dart';
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

      final result = await searchVideos('测试');
      expect(result.videos.single.avid, 170001);
      expect(result.videos.single.cover, 'https://i0.hdslb.com/cover.jpg');
    });

    test('解析总数与总页数（用于结果头部与翻页判断）', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'numResults': 1234,
            'numPages': 62,
            'result': [_searchItem()],
          },
        }),
      );

      final result = await searchVideos('测试');
      expect(result.total, 1234);
      expect(result.pages, 62);
    });

    test('请求携带页码、排序与时长筛选参数', () async {
      final adapter = _mock();
      Map<String, dynamic>? captured;
      adapter.onGet(
        url,
        (server) => server.replyCallback(200, (options) {
          captured = options.queryParameters;
          return {
            'code': 0,
            'data': {'result': []},
          };
        }),
      );

      await searchVideos(
        '测试',
        page: 3,
        order: SearchOrder.click,
        duration: SearchDuration.medium,
      );

      expect(captured?['search_type'], 'video');
      expect(captured?['keyword'], '测试');
      expect(captured?['page'], 3);
      expect(captured?['order'], 'click');
      expect(captured?['duration'], 2);
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

      final result = await searchVideos('测试');
      expect(result.videos.length, 1);
    });

    test('result 缺失时返回空结果', () async {
      final adapter = _mock();
      adapter.onGet(url, (server) => server.reply(200, {'code': 0, 'data': {}}));

      final result = await searchVideos('测试');
      expect(result.videos, isEmpty);
      expect(result.total, 0);
      expect(result.pages, 0);
    });
  });

  group('searchHotWords', () {
    const url = 'https://api.bilibili.com/x/web-interface/wbi/search/square';

    test('解析热搜关键词，keyword 为空时回退 show_name', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'trending': {
              'list': [
                {'keyword': '热搜甲'},
                {'keyword': '', 'show_name': '热搜乙'},
                {'show_name': '热搜丙'},
                {'keyword': '   '},
              ],
            },
          },
        }),
      );

      expect(await searchHotWords(), ['热搜甲', '热搜乙', '热搜丙']);
    });

    test('列表缺失或坏项时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      expect(await searchHotWords(), isEmpty);
    });
  });

  group('searchSuggest', () {
    const url = 'https://s.search.bilibili.com/main/suggest';

    test('解析联想词并去重、过滤空值', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'result': {
            'tag': [
              {'value': '洛天依'},
              {'value': '洛天依'},
              {'value': '  '},
              {'value': '洛天依演唱会'},
            ],
          },
        }),
      );

      expect(await searchSuggest('洛'), ['洛天依', '洛天依演唱会']);
    });

    test('业务错误抛出 BilibiliError', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': -412, 'message': '请求被拦截'}),
      );

      await expectLater(
        searchSuggest('洛'),
        throwsA(
          isA<BilibiliError>()
              .having((e) => e.code, 'code', -412)
              .having((e) => e.message, 'message', '请求被拦截'),
        ),
      );
    });

    test('result 缺失时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(url, (server) => server.reply(200, {'code': 0}));

      expect(await searchSuggest('洛'), isEmpty);
    });
  });
}
