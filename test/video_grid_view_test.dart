import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
