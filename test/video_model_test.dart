import 'package:blt/models/video.dart';
import 'package:flutter_test/flutter_test.dart';

// 搜索接口的video结果：id字段是aid，不包含cid
Map<String, dynamic> _searchVideoJson() => {
  'type': 'video',
  'id': 170001,
  'aid': 170001,
  'bvid': 'BV17x411w7KC',
  'title': '测试<em class="keyword">视频</em>标题',
  'pic': '//i0.hdslb.com/bfs/archive/cover.jpg',
  'duration': '1:02:03',
  'mid': 123,
  'author': '测试UP主',
  'upic': '//i0.hdslb.com/bfs/face/avatar.jpg',
  'pubdate': 1700000000,
};

Map<String, dynamic> _feedVideoJson() => {
  'goto': 'av',
  'aid': 170001,
  'bvid': 'BV17x411w7KC',
  'cid': 279786,
  'title': '测试视频标题',
  'pic': 'https://i0.hdslb.com/bfs/archive/cover.jpg',
  'duration': 3723,
  'progress': 10,
  'stat': {'view': '1000', 'like': 3},
  'owner': {'mid': 123, 'name': '测试UP主', 'face': 'avatar.jpg'},
  'pubdate': 1700000000,
};

void main() {
  group('MediaCardInfo.fromSearchJson', () {
    test('不把id(aid)当作cid', () {
      final video = MediaCardInfo.fromSearchJson(_searchVideoJson());

      expect(video, isNotNull);
      expect(video!.cid, isNull);
      expect(video.avid, 170001);
      expect(video.bvid, 'BV17x411w7KC');
    });

    test('解析时长与去除标题高亮标签', () {
      final video = MediaCardInfo.fromSearchJson(_searchVideoJson());

      expect(video!.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(video.title, '测试视频标题');
    });

    test('核心字段（aid/标题）缺失时返回 null', () {
      expect(MediaCardInfo.fromSearchJson({'title': 'x'}), isNull);
      expect(MediaCardInfo.fromSearchJson({'aid': 1}), isNull);
      expect(
        MediaCardInfo.fromSearchJson({
          ..._searchVideoJson(),
          'title': '',
        }),
        isNull,
      );
    });

    test('次要字段类型错时降级默认值，不抛异常', () {
      final video = MediaCardInfo.fromSearchJson({
        ..._searchVideoJson(),
        'pic': 123,
        'duration': true,
        'mid': 'not-a-number',
        'pubdate': null,
      });

      expect(video, isNotNull);
      expect(video!.cover, '');
      expect(video.duration, Duration.zero);
      expect(video.userMid, 0);
      expect(video.publishTime.millisecondsSinceEpoch, 0);
    });
  });

  group('MediaCardInfo.fromJson', () {
    test('正常解析并容错统计数字字符串', () {
      final video = MediaCardInfo.fromJson(_feedVideoJson());

      expect(video!.avid, 170001);
      expect(video.cid, 279786);
      expect(video.stat?.viewCount, 1000);
      expect(video.progress?.progress, 10);
    });

    test('owner 缺失时用户字段降级默认值', () {
      final video = MediaCardInfo.fromJson({
        ..._feedVideoJson(),
        'owner': null,
      });

      expect(video, isNotNull);
      expect(video!.userMid, 0);
      expect(video.userName, '');
    });

    test('aid/标题非法时返回 null', () {
      expect(
        MediaCardInfo.fromJson({
          ..._feedVideoJson(),
          'aid': 'x',
          'id': null,
        }),
        isNull,
      );
    });
  });

  group('MediaCardInfo.fromHistoryJson', () {
    test('history 缺失（核心字段）返回 null', () {
      expect(
        MediaCardInfo.fromHistoryJson({
          'title': 'x',
          'goto': 'av',
        }),
        isNull,
      );
    });

    test('view_at 类型错时降级 epoch，不抛异常', () {
      final video = MediaCardInfo.fromHistoryJson({
        'history': {'oid': 170001, 'bvid': 'BV1', 'cid': 2},
        'title': '历史视频',
        'goto': 'av',
        'view_at': 'bad',
      });

      expect(video, isNotNull);
      expect(video!.publishTime.millisecondsSinceEpoch, 0);
    });
  });

  group('MediaCardInfo.fromDynamicJson', () {
    test('modules 链路缺失时返回 null', () {
      expect(MediaCardInfo.fromDynamicJson({}), isNull);
      expect(
        MediaCardInfo.fromDynamicJson({
          'modules': {'module_dynamic': {}},
        }),
        isNull,
      );
    });

    test('aid 字符串与 pub_ts 字符串正常解析', () {
      final video = MediaCardInfo.fromDynamicJson({
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
      });

      expect(video!.avid, 170001);
      expect(video.duration, const Duration(minutes: 10, seconds: 30));
      expect(video.publishTime.millisecondsSinceEpoch,
          1700000000 * Duration.millisecondsPerSecond);
    });
  });

  group('Video.fromJson', () {
    test('核心字段（aid/标题）缺失时返回 null', () {
      expect(Video.fromJson({'title': 'x'}), isNull);
      expect(Video.fromJson({'aid': 1}), isNull);
    });

    test('cid 缺失时回退到第一个分P', () {
      final video = Video.fromJson({
        'aid': 170001,
        'title': '标题',
        'pages': [
          {'page': 1, 'cid': 279786, 'part': 'P1', 'duration': 60},
          {'page': 2, 'cid': 279787, 'part': 'P2', 'duration': 60},
        ],
      });

      expect(video!.cid, 279786);
      expect(video.episodes.length, 2);
    });

    test('pages 坏项丢弃、类型错降级默认值', () {
      final video = Video.fromJson({
        'aid': 170001,
        'title': '标题',
        'pages': [
          {'page': 1, 'cid': 279786, 'part': 'P1', 'duration': 60},
          'bad-item',
          {'page': 'x', 'cid': 'y', 'part': 1, 'duration': null},
        ],
        'stat': {'view': 'x'},
        'pubdate': null,
      });

      expect(video!.episodes.length, 2);
      expect(video.stat.viewCount, 0);
      expect(video.publishTime.millisecondsSinceEpoch, 0);
    });
  });
}
