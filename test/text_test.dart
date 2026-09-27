import 'package:blt/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TextStyle> _pumpAndReadStyle(
  WidgetTester tester, {
  required double width,
  required double height,
  double? maxFontSize,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: FixedLineAdaptiveText(
            '测试标题',
            line: 2,
            lineHeight: 1.4,
            maxFontSize: maxFontSize,
          ),
        ),
      ),
    ),
  );
  return tester.widget<Text>(find.text('测试标题')).style!;
}

void main() {
  testWidgets('未设置上限时按容器高度自适应', (tester) async {
    final style = await _pumpAndReadStyle(tester, width: 300, height: 200);
    // 200 / (2 * 1.4)
    expect(style.fontSize, closeTo(200 / 2.8, 1e-6));
  });

  testWidgets('字号不超过 maxFontSize', (tester) async {
    final style = await _pumpAndReadStyle(
      tester,
      width: 300,
      height: 200,
      maxFontSize: 20,
    );
    expect(style.fontSize, 20);
  });

  testWidgets('maxFontSize 小于1时也不报错', (tester) async {
    final style = await _pumpAndReadStyle(
      tester,
      width: 10,
      height: 200,
      maxFontSize: 0.5,
    );
    expect(style.fontSize, 1.0);
  });
}
