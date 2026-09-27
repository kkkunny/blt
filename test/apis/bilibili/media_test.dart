import 'dart:convert';
import 'dart:typed_data';

import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/media.dart';
import 'package:blt/models/pbs/dm.pb.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Quality.fromJson', () {
    test('清晰度 id 缺失时返回 null', () {
      expect(Quality.fromJson({'new_description': '1080P'}), isNull);
      expect(Quality.fromJson({'quality': 'bad', 'id': null}), isNull);
    });

    test('description 类型错降级默认值', () {
      final quality = Quality.fromJson({'quality': 80, 'new_description': 1});
      expect(quality!.id, 80);
      expect(quality.description, '');
    });
  });

  group('DashMediaData.fromJson', () {
    test('播放地址缺失时返回 null', () {
      expect(DashMediaData.fromJson({'id': 32}), isNull);
      expect(DashMediaData.fromJson({'base_url': ''}), isNull);
    });

    test('backup_url 坏项过滤、类型错降级', () {
      final media = DashMediaData.fromJson({
        'id': '32',
        'base_url': 'https://example.com/v.m4s',
        'backup_url': ['https://a.com', 123, null],
      });
      expect(media!.quality, 32);
      expect(media.backupUrls, ['https://a.com']);
    });
  });

  group('GetVideoPlayURLResponse.fromJson', () {
    test('dash 缺失时不抛异常', () {
      final resp = GetVideoPlayURLResponse.fromJson({'quality': 80});
      expect(resp.defaultQualityID, 80);
      expect(resp.dashData.video, isEmpty);
      expect(resp.dashData.audio, isEmpty);
    });

    test('坏线路丢弃、好线路保留', () {
      final resp = GetVideoPlayURLResponse.fromJson({
        'quality': '80',
        'support_formats': [
          {'quality': 80, 'new_description': '1080P'},
          {'new_description': '坏项'},
        ],
        'dash': {
          'video': [
            {'id': 32, 'base_url': 'https://example.com/v.m4s'},
            {'id': 16},
          ],
          'audio': [
            {'id': 30280, 'base_url': 'https://example.com/a.m4s'},
          ],
        },
      });
      expect(resp.defaultQualityID, 80);
      expect(resp.supportFormats.length, 1);
      expect(resp.dashData.video.length, 1);
      expect(resp.dashData.audio.length, 1);
    });
  });

  group('ArchiveRelation.fromJson', () {
    test('布尔/整型混用均容错', () {
      final relation = ArchiveRelation.fromJson({
        'like': 1,
        'dislike': false,
        'favorite': 'bad',
        'coin': '2',
        'season_fav': 0,
      });
      expect(relation.like, true);
      expect(relation.dislike, false);
      expect(relation.favorite, false);
      expect(relation.coin, 2);
      expect(relation.seasonFav, false);
    });
  });

  group('getVideoInfo', () {
    const url = 'https://api.bilibili.com/x/web-interface/view';

    test('正常解析视频信息', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'aid': 170001,
            'bvid': 'BV1',
            'title': '标题',
            'cid': 279786,
          },
        }),
      );

      final video = await getVideoInfo(avid: 170001);
      expect(video.avid, 170001);
      expect(video.cid, 279786);
    });

    test('视频信息不完整时抛 BilibiliError 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'title': '只有标题'},
        }),
      );

      await expectLater(
        getVideoInfo(avid: 170001),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });

  group('getDanmaku', () {
    const url = 'https://api.bilibili.com/x/v2/dm/web/seg.so';

    test('protobuf 弹幕正常解析', () async {
      final reply = DmSegMobileReply();
      reply.elems.add(DanmakuElem()..id = Int64(1)..content = '弹幕');
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(
          200,
          reply.writeToBuffer(),
          headers: {
            Headers.contentTypeHeader: ['application/octet-stream'],
          },
        ),
      );

      final result = await getDanmaku(279786, 1);
      expect(result.elems.single.content, '弹幕');
    });

    test('非 protobuf 响应抛 BilibiliError 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(
          200,
          Uint8List.fromList(utf8.encode('<html>风控</html>')),
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      await expectLater(
        getDanmaku(279786, 1),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });
}
