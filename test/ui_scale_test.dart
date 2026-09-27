import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UiScale.factorFor', () {
    test('1920x1080 为设计基准', () {
      expect(UiScale.factorFor(const Size(1920, 1080)), 1.0);
    });

    test('720p 按比例缩小', () {
      expect(UiScale.factorFor(const Size(1280, 720)), closeTo(2 / 3, 1e-9));
    });

    test('4K 按比例放大', () {
      expect(UiScale.factorFor(const Size(3840, 2160)), 2.0);
    });

    test('超宽屏由高度限制', () {
      expect(UiScale.factorFor(const Size(2560, 1080)), 1.0);
    });

    test('4:3 屏幕由宽度限制，避免横向溢出', () {
      expect(
        UiScale.factorFor(const Size(1600, 1200)),
        closeTo(1600 / 1920, 1e-9),
      );
    });
  });

  group('UiScale.border', () {
    test('低分辨率下描边不小于1逻辑像素', () {
      expect(UiScale.border(2, 0.3), 1.0);
    });

    test('常规分辨率按缩放系数计算', () {
      expect(UiScale.border(2, 0.667), closeTo(1.334, 1e-3));
    });
  });

  testWidgets('context.ui 从最近 UiScale 读取缩放系数', (tester) async {
    late double ui;
    await tester.pumpWidget(
      UiScale(
        factor: 0.75,
        child: Builder(
          builder: (context) {
            ui = context.ui;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(ui, 0.75);
  });

  testWidgets('UiScaleScope 按窗口尺寸挂载缩放并禁用系统字体缩放', (tester) async {
    late BuildContext childContext;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1280, 720)),
        child: UiScaleScope(
          child: Builder(
            builder: (context) {
              childContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(childContext.ui, closeTo(2 / 3, 1e-9));
    expect(MediaQuery.textScalerOf(childContext), TextScaler.noScaling);
  });
}
