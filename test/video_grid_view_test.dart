import 'package:blt/models/video.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/page_test_env.dart';

SliverGridRegularTileLayout _layoutOf(
  SliverGridDelegate delegate, {
  required Axis scrollDirection,
  required double crossAxisExtent,
}) {
  return delegate.getLayout(
        SliverConstraints(
          axisDirection: scrollDirection == Axis.horizontal
              ? AxisDirection.right
              : AxisDirection.down,
          growthDirection: GrowthDirection.forward,
          userScrollDirection: ScrollDirection.idle,
          scrollOffset: 0,
          precedingScrollExtent: 0,
          overlap: 0,
          crossAxisExtent: crossAxisExtent,
          crossAxisDirection: scrollDirection == Axis.horizontal
              ? AxisDirection.down
              : AxisDirection.right,
          viewportMainAxisExtent: 1920,
          remainingPaintExtent: 1920,
          remainingCacheExtent: 1920,
          cacheOrigin: 0,
        ),
      )
      as SliverGridRegularTileLayout;
}

void main() {
  group('buildVideoGridDelegate', () {
    test('横向列表：卡片宽高比不反转', () {
      final delegate = buildVideoGridDelegate(
        scrollDirection: Axis.horizontal,
        ui: 1,
        cardAspectRatio: 1.2,
        crossAxisCount: 1,
      );
      final layout = _layoutOf(
        delegate,
        scrollDirection: Axis.horizontal,
        crossAxisExtent: 600,
      );
      expect(layout.childCrossAxisExtent, 600);
      expect(layout.childMainAxisExtent, closeTo(720, 1e-9));
    });

    test('纵向固定列数：卡片宽高比同样不反转', () {
      final delegate = buildVideoGridDelegate(
        scrollDirection: Axis.vertical,
        ui: 1,
        cardAspectRatio: 1.2,
        crossAxisCount: 4,
      );
      final layout = _layoutOf(
        delegate,
        scrollDirection: Axis.vertical,
        crossAxisExtent: 1920,
      );
      expect(layout.childCrossAxisExtent, closeTo(462, 1e-9));
      expect(layout.childMainAxisExtent, closeTo(385, 1e-9));
    });

    test('间距按 ui 缩放', () {
      final delegate = buildVideoGridDelegate(
        scrollDirection: Axis.vertical,
        ui: 0.667,
        cardAspectRatio: 1.2,
        crossAxisCount: 4,
      );
      final layout = _layoutOf(
        delegate,
        scrollDirection: Axis.vertical,
        crossAxisExtent: 1280,
      );
      expect(
        layout.mainAxisStride - layout.childMainAxisExtent,
        closeTo(24 * 0.667, 1e-9),
      );
      expect(
        layout.crossAxisStride - layout.childCrossAxisExtent,
        closeTo(24 * 0.667, 1e-9),
      );
    });

    test('最大卡片尺寸按 ui 缩放', () {
      final delegate = buildVideoGridDelegate(
        scrollDirection: Axis.vertical,
        ui: 2,
        cardAspectRatio: 1.2,
      );
      expect(
        (delegate as SliverGridDelegateWithMaxCrossAxisExtent)
            .maxCrossAxisExtent,
        1200,
      );
    });
  });

  group('VideoGridView 挂载行为', () {
    MediaCardInfo video(int avid) => MediaCardInfo(
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

    testWidgets('默认挂载即加载首屏', (tester) async {
      var calls = 0;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls++;
          return ([video(1)], false);
        },
      );

      await pumpPage(
        tester,
        SizedBox(height: 800, child: VideoGridView(provider: provider)),
      );
      await tester.pump();

      expect(calls, 1);
      // 排空分页组件内部的延迟滚动定时器
      await tester.pump(const Duration(seconds: 1));
      provider.dispose();
    });

    testWidgets('autoRefresh=false 时由页面自己控制首屏', (tester) async {
      var calls = 0;
      final provider = VideoGridViewProvider(
        onLoad: ({bool isFetchMore = false}) async {
          calls++;
          return ([video(1)], false);
        },
      );

      await pumpPage(
        tester,
        SizedBox(
          height: 800,
          child: VideoGridView(provider: provider, autoRefresh: false),
        ),
      );
      await tester.pump();

      expect(calls, 0);
      provider.dispose();
    });
  });
}
