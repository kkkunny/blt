import 'dart:math' as math;

import 'package:blt/models/video.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

MediaCardInfo _video(int avid) => MediaCardInfo(
  type: MediaType.video,
  avid: avid,
  bvid: 'BV$avid',
  title: '视频$avid',
  cover: '',
  duration: const Duration(seconds: 10),
  userMid: 1,
  userName: 'up',
  userAvatar: '',
  publishTime: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  group('VideoGridViewProvider 分页契约', () {
    test('首屏请求isFetchMore=false，翻页请求isFetchMore=true', () async {
      final calls = <bool>[];
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls.add(isFetchMore);
          return ([_video(calls.length)], true);
        },
      );

      await provider.debugFetchPage(1);
      await provider.debugFetchPage(2);

      expect(calls, [false, true]);
      provider.dispose();
    });

    test('请求失败后刷新状态恢复，可重试成功', () async {
      var shouldThrow = true;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          if (shouldThrow) throw Exception('network');
          return ([_video(1)], false);
        },
      );

      // 不应抛出异常
      await provider.refresh();
      expect(provider.debugRefreshing, isFalse);

      shouldThrow = false;
      await provider.refresh();
      expect(provider.debugRefreshing, isFalse);
      expect(provider.length, 1);
      provider.dispose();
    });

    test('并发拉取只发起一次请求', () async {
      var calls = 0;
      var concurrent = 0;
      var maxConcurrent = 0;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls++;
          concurrent++;
          maxConcurrent = math.max(maxConcurrent, concurrent);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          concurrent--;
          return ([_video(calls)], true);
        },
      );

      await Future.wait([
        provider.fetchData(isFetchMore: true),
        provider.fetchData(isFetchMore: true),
      ]);

      expect(calls, 1);
      expect(maxConcurrent, 1);
      provider.dispose();
    });

    test('首屏失败后重试重跑首屏请求', () async {
      final calls = <bool>[];
      var fail = true;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls.add(isFetchMore);
          if (fail) throw Exception('network');
          return ([_video(1)], false);
        },
      );

      await provider.refresh();
      expect(provider.isEmpty, isTrue);

      fail = false;
      await provider.retry();

      expect(calls, [false, false]);
      expect(provider.length, 1);
      provider.dispose();
    });

    test('加载更多失败后重试重跑翻页请求，且不丢失已有数据', () async {
      final calls = <bool>[];
      var fail = false;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls.add(isFetchMore);
          if (fail) throw Exception('network');
          return ([_video(calls.length)], true);
        },
      );

      await provider.refresh();
      expect(provider.length, 1);

      fail = true;
      await provider.fetchData(isFetchMore: true);
      // 失败不清空已加载的数据
      expect(provider.length, 1);

      fail = false;
      await provider.retry();

      expect(calls, [false, true, true]);
      expect(provider.length, 2);
      provider.dispose();
    });
  });
}
