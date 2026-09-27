import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/focus_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required double ui, required Widget child}) => UiScale(
  factor: ui,
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('展示当前/总时长', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: const SizedBox(
          width: 1200,
          child: FocusProgressBar(
            position: Duration(seconds: 6),
            duration: Duration(seconds: 33),
          ),
        ),
      ),
    );

    expect(find.text('0:06'), findsOneWidget);
    expect(find.text('0:33'), findsOneWidget);
  });

  testWidgets('左右键拖动预览，确认键提交 seek', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    Duration? seeked;
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: SizedBox(
          width: 1200,
          child: FocusProgressBar(
            position: const Duration(seconds: 10),
            duration: const Duration(seconds: 100),
            buffered: const Duration(seconds: 40),
            onPositionChanged: (position) => seeked = position,
          ),
        ),
      ),
    );

    expect(find.text('0:10'), findsOneWidget);
    expect(find.text('1:40'), findsOneWidget);

    Focus.of(tester.element(find.byType(ProgressBar))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('0:11'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('0:12'), findsOneWidget);
    expect(seeked, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(seeked, const Duration(seconds: 12));
  });

  testWidgets('拖动越界时钳制在时长范围内', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    Duration? seeked;
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: SizedBox(
          width: 1200,
          child: FocusProgressBar(
            position: const Duration(seconds: 0),
            duration: const Duration(seconds: 100),
            onPositionChanged: (position) => seeked = position,
          ),
        ),
      ),
    );

    Focus.of(tester.element(find.byType(ProgressBar))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('0:00'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(seeked, isNull);
  });

  for (final (name, size) in [
    ('720p', const Size(1280, 720)),
    ('1080p', const Size(1920, 1080)),
    ('4K', const Size(3840, 2160)),
  ]) {
    testWidgets('进度条在$name下无溢出', (tester) async {
      _setScreen(tester, size);
      await tester.pumpWidget(
        _host(
          ui: UiScale.factorFor(size),
          child: const SizedBox(
            width: 1200,
            child: FocusProgressBar(
              position: Duration(seconds: 6),
              duration: Duration(seconds: 33),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
