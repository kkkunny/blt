import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/models/video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

Map<String, dynamic> _toViewItem() => {
  'aid': 170001,
  'bvid': 'BV1',
  'cid': 279786,
  'title': '稍后再看视频',
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

  group('MediaCardInfo.fromToViewJson', () {
    test('核心字段（aid/标题）缺失时返回 null', () {
      expect(MediaCardInfo.fromToViewJson({'title': 'x'}), isNull);
      expect(MediaCardInfo.fromToViewJson({'aid': 1}), isNull);
    });
  });

  group('listToView', () {
    const url = 'https://api.bilibili.com/x/v2/history/toview/web';

    test('坏项丢弃、好项保留', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'list': [_toViewItem(), {'title': '缺 aid'}, 'bad'],
          },
        }),
      );

      final videos = await listToView();
      expect(videos.length, 1);
      expect(videos.single.avid, 170001);
    });

    test('data/list 缺失时返回空列表', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': null}),
      );

      expect(await listToView(), isEmpty);
    });
  });
}
